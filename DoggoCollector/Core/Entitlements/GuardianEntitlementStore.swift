//
//  GuardianEntitlementStore.swift
//  DoggoCollector
//
//  The only place StoreKit is touched (same single-owner pattern as
//  MedicationReminder for notifications). One product: a non-consumable
//  lifetime unlock for Guardian Mode.
//
//  Freemium pivot (decision #25): the gate moved from "the pledge" to
//  "the 7th pledge" — the first 6 wards on an account are free, and this
//  unlock is what buys unlimited wards after that. Catching/collection/
//  sharing stay free forever regardless. `canPledge`/`freeSlotsRemaining`
//  take the caller's current ward count as a plain argument rather than
//  querying the store themselves — this type has no ModelContext access,
//  and doesn't need one.
//
//  Deliberately NOT gated: accepting an incoming Guardian Handover
//  (HandoverAcceptSheet) — receiving responsibility for a dog someone
//  else already looks after is not the same act as pledging, and blocking
//  an accept would strand the sender mid-transfer. (`CaughtDog.receivedViaHandover`
//  also keeps a received ward out of the free-slot count itself.)
//
//  Testing note: StoreKit configuration files (DoggoCollector.storekit at
//  the repo root, wired into the shared scheme) only take effect when the
//  app is launched by Xcode/xcodebuild — a bare simctl/devicectl launch
//  talks to the real App Store instead, where the product won't exist
//  until it's created in App Store Connect with this exact product ID.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class GuardianEntitlementStore {
    static let productID = "com.DoggoCollector.guardian.lifetime"
    /// Pledges 1–6 on an account are free; the unlock is what buys
    /// pledge 7 onward. See `~/Documents/guardian_paywall_v2_implementation.md`.
    static let freeWardAllowance = 6

    /// True once a verified, unrevoked purchase of the lifetime unlock
    /// exists on this Apple ID. Defaults false until the first
    /// currentEntitlements pass completes — the paywall is the only UI
    /// consequence of that brief window, and it re-checks before purchase.
    private(set) var isUnlocked = false
    /// Loaded lazily; nil means the store hasn't been reached yet (offline,
    /// or the product doesn't exist in this environment) — the paywall
    /// shows a retry state rather than a broken price button.
    private(set) var product: Product?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Apple's own guidance: start listening for transaction updates
        // (renewals don't apply to a non-consumable, but refunds,
        // Ask to Buy approvals, and purchases made on another device do)
        // as close to app launch as possible, and finish() everything.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? Self.checkVerified(update) {
                    await transaction.finish()
                    await self.refreshEntitlement()
                }
            }
        }
        Task {
            await refreshEntitlement()
            await loadProductIfNeeded()
        }
    }

    enum PurchaseOutcome {
        case unlocked
        /// Deferred approval (e.g. Ask to Buy) — not a failure; the
        /// Transaction.updates listener flips isUnlocked when it clears.
        case pending
        case cancelled
    }

    func purchase() async throws -> PurchaseOutcome {
        await loadProductIfNeeded()
        guard let product else { throw StoreError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            isUnlocked = true
            return .unlocked
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// "Restore purchase" — forces a sync with the App Store (prompts for
    /// Apple ID credentials if needed), then re-reads entitlements.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    /// `currentWardCount` should be the caller's own-pledge count (excluding
    /// `receivedViaHandover` dogs) — see `CardDetailView`'s `wardCount`.
    func canPledge(currentWardCount: Int) -> Bool {
        isUnlocked || currentWardCount < Self.freeWardAllowance
    }

    func freeSlotsRemaining(currentWardCount: Int) -> Int {
        max(0, Self.freeWardAllowance - currentWardCount)
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productID]).first
    }

    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.productID == Self.productID {
                isUnlocked = true
                return
            }
        }
        // No matching entitlement found (also the refund path — a revoked
        // transaction drops out of currentEntitlements entirely).
        isUnlocked = false
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: Error {
        case productUnavailable
        case failedVerification
    }
}
