//
//  GuardianPledgeSheet.swift
//  DoggoCollector
//
//  B1 — the pledge flow. Presented from Card Detail's pre-pledge banner.
//  The CTA mutates the dog directly (isWard/pledgedAt), auto-assigns the
//  nearest clinic as a point-in-time snapshot, then hands control back to
//  the caller (which dismisses, toasts, and switches to Dossier).
//
//  Paywall v2 (decision #25): ONE screen for every pledge, built to match
//  the approved "Guardian Paywall.dc.html" prototype, whose full structure
//  (layout, sizes, colors, SVG geometry, per-element animation timings) was
//  extracted live from the design tool via its GetFile RPC. The prototype
//  is authored at 390x844, so every px below maps 1:1 to points.
//
//  Layout is a three-part flex column, NOT one big ScrollView (an earlier
//  pass scrolled everything, which is why the sheet read as an endless
//  column rather than a composed screen):
//    - a fixed header  (drag handle + close)
//    - a scrolling middle (hero, headline, benefit rows, expander, reassurance)
//    - a pinned footer (CTA, restore, AWBI note) that never scrolls away
//
//  The prototype has no separate "free" treatment — every pledge plays the
//  same ceremony. Only the CTA differs: wards 1-6 (or an already-unlocked
//  account) pledge instantly with no StoreKit involved; ward 7+ runs a real
//  purchase first, through the same state machine, into the same success
//  ceremony. `wardCount` (the caller's own-pledge count, excluding received
//  Handovers) decides which.
//

import SwiftUI
import CoreLocation
import StoreKit

struct GuardianPledgeSheet: View {
    @Bindable var dog: CaughtDog
    var wardCount: Int
    var onPledge: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(GuardianEntitlementStore.self) private var entitlements
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// StoreKit-purchase states, mirroring the prototype's own `payState`
    /// machine one-for-one. On the free path only `.ready`/`.success` are
    /// ever meaningful — the CTA there never consults the product.
    private enum PayState: Equatable {
        case loading, unreachable, ready, purchasing, askPending, error, success
    }
    @State private var payState: PayState = .loading
    @State private var restoreMessage: String?
    @State private var errorMessage: String?
    @State private var expanded = false

    // Ceremony state — driven only by `runEntrance()`/`runSuccess()`.
    @State private var ribbonProgress: CGFloat = 0
    @State private var knotScale: CGFloat = 0.001
    @State private var ribbonFlash = false
    @State private var headlineIn = false
    @State private var rowsIn = false
    @State private var showGuardianTag = false
    @State private var burstID = 0
    @State private var successHaptic = false
    @State private var knotHaptic = false

    private var canPledgeFree: Bool {
        entitlements.canPledge(currentWardCount: wardCount)
    }
    private var isSuccess: Bool { payState == .success }

    var body: some View {
        VStack(spacing: 0) {
            header
            scrollingBody
            footer
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)   // the design draws its own
        .task { await runEntrance() }
        .sensoryFeedback(.success, trigger: successHaptic)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: knotHaptic)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Capsule()
                .fill(DoggoColor.paywallRowBorder)
                .frame(width: 38, height: 5)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("\u{2715}")
                        .font(DoggoFont.body(13, weight: .bold))
                        .foregroundStyle(DoggoColor.inkMuted)
                        .frame(width: 30, height: 30)
                        .background(DoggoColor.provEstBg, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    // MARK: - Scrolling middle

    private var scrollingBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                    .padding(.top, 4)

                headline
                    .padding(.top, 14)

                if !isSuccess {
                    benefitRows
                        .padding(.top, 14)

                    expander
                        .padding(.top, 12)

                    Text("Catching and collecting dogs stays free forever. This unlocks caring for them.")
                        .font(DoggoFont.body(11.5))
                        .foregroundStyle(DoggoColor.paywallFaint)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 12)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ScoutMascot(
                expression: .happy,
                size: 104,
                wearsGuardianMedal: true,
                ribbonDrawProgress: reduceMotion ? 1 : ribbonProgress,
                ribbonKnotScale: reduceMotion ? 1 : knotScale
            )
            .brightness(ribbonFlash ? 0.35 : 0)
            .floatingIdle(distance: 5, duration: 1.6)

            miniCard
        }
    }

    private var miniCard: some View {
        VStack(spacing: 6) {
            Group {
                if let image = DogPhoto.image(from: dog.imageData, size: .tile, cacheKey: dog.id.uuidString) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    PolkaDotPlaceholder(seed: dog.id.hashValue)
                }
            }
            .frame(width: 84, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(dog.name)
                .font(DoggoFont.display(13, weight: .bold))
                .foregroundStyle(DoggoColor.ink)
                .lineLimit(1)
        }
        .padding(8)
        .frame(width: 100)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 20))
        // The design's shadows all carry a large negative spread
        // (`0 14px 30px -16px`), which SwiftUI has no equivalent for — so
        // every one of them is re-tuned to a tighter, lighter approximation
        // rather than mapping blur straight to radius, which reads as a
        // heavy glow instead of a lift.
        .shadow(color: .black.opacity(0.20), radius: 9, y: 8)
        .overlay(alignment: .topTrailing) {
            if showGuardianTag {
                Text("GUARDIAN")
                    .font(DoggoFont.body(9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DoggoColor.marigold, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: DoggoColor.marigold.opacity(0.5), radius: 4, y: 4)
                    .rotationEffect(.degrees(-14))
                    .offset(x: 10, y: -8)
                    .transition(.scale(scale: 0).combined(with: .opacity))
            }
        }
        .rotationEffect(.degrees(4))
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(isSuccess ? "You're \(dog.name)'s Guardian now." : "Become \(dog.name)'s Guardian")
                .font(DoggoFont.display(isSuccess ? 23 : 25, weight: .bold))
                .foregroundStyle(DoggoColor.ink)
                .multilineTextAlignment(.center)

            Text(isSuccess
                 ? "Their dossier is ready \u{2014} opening it for you\u{2026}"
                 : "You'll be the one who looks out for them. Here's everything that comes with it:")
                .font(DoggoFont.body(13.5))
                .foregroundStyle(DoggoColor.inkMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: isSuccess ? 260 : 275)

            // The freemium pivot's one copy addition beyond the approved
            // design — only shown when a purchase is actually on the table.
            if !isSuccess && !canPledgeFree {
                Text("Your first six wards were on the house. This unlocks every dog after \u{2014} once, forever.")
                    .font(DoggoFont.body(11.5))
                    .foregroundStyle(DoggoColor.paywallFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 275)
                    .padding(.top, 2)
            }
        }
        .id(isSuccess)
        .transition(.opacity)
        .opacity(headlineIn || reduceMotion ? 1 : 0)
        .offset(y: headlineIn || reduceMotion ? 0 : 12)
        .frame(minHeight: 64)
    }

    // MARK: - Benefit rows

    private var benefitRows: some View {
        VStack(spacing: 8) {
            ForEach(Array(Self.benefits.enumerated()), id: \.offset) { index, benefit in
                benefitRow(benefit, index: index)
                    .opacity(rowsIn || reduceMotion ? 1 : 0)
                    .offset(y: rowsIn || reduceMotion ? 0 : 12)
                    .animation(
                        reduceMotion ? nil
                        : .easeOut(duration: 0.4).delay(Double(index) * 0.06),
                        value: rowsIn
                    )
            }
        }
    }

    private func benefitRow(_ benefit: Benefit, index: Int) -> some View {
        HStack(alignment: .center, spacing: 11) {
            iconTile(benefit, index: index)

            // One flowing sentence — bold lead-in, muted continuation —
            // rather than a stacked title/subtitle, matching the design.
            (Text(benefit.title).font(DoggoFont.body(14, weight: .bold)).foregroundColor(DoggoColor.ink)
             + Text(" \u{2014} " + benefit.detail).font(DoggoFont.body(13)).foregroundColor(DoggoColor.paywallRowText))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 16))
        // The first row is outlined; the rest are lifted on a soft shadow.
        .overlay {
            if index == 0 {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(DoggoColor.paywallRowBorder, lineWidth: 1.5)
            }
        }
        .shadow(
            color: index == 0 ? .clear : .black.opacity(0.10),
            radius: 5, y: 4
        )
    }

    private func iconTile(_ benefit: Benefit, index: Int) -> some View {
        BenefitSymbol(benefit: benefit, index: index, animates: !reduceMotion)
            .frame(width: 36, height: 36)
            .background {
                if let fill = benefit.tileFill {
                    RoundedRectangle(cornerRadius: 11).fill(fill)
                } else {
                    RoundedRectangle(cornerRadius: 11).strokeBorder(benefit.iconColor, lineWidth: 2)
                }
            }
            .overlay {
                // A slow diagonal sheen crossing one tile at a time — the
                // prototype runs a 24s cycle per tile, staggered 6s apart,
                // visible only between 8% and 22% of it. Scoped to this
                // overlay so the row's text isn't re-rendered every frame.
                if !reduceMotion {
                    TimelineView(.animation) { context in
                        let cycle = 24.0
                        let phase = (context.date.timeIntervalSinceReferenceDate + Double(index) * 6)
                            .truncatingRemainder(dividingBy: cycle) / cycle
                        TileSheen(progress: phase)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: - Expander

    private var expander: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Text("Everything included")
                        .font(DoggoFont.body(12, weight: .bold))
                        .foregroundStyle(DoggoColor.paywallFaint)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DoggoColor.paywallFaint)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(Self.everythingIncluded.enumerated()), id: \.offset) { i, item in
                        Text("\(i + 1). \(item)")
                            .font(DoggoFont.body(12))
                            .foregroundStyle(DoggoColor.paywallRowText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(DoggoColor.paywallListBg, in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Pinned footer

    private var footer: some View {
        VStack(spacing: 0) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DoggoFont.body(12))
                    .foregroundStyle(DoggoColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.bottom, 9)
            }

            ctaPill
                // The prototype fires the burst from a point 40pt down the
                // footer — dead center of the CTA — so the spray reads as
                // coming out of the button that was just tapped.
                .overlay { PawBurstView(burstID: reduceMotion ? 0 : burstID) }

            if payState == .askPending {
                Text("Waiting for approval \u{2014} the pledge completes once it's confirmed.")
                    .font(DoggoFont.body(11.5))
                    .foregroundStyle(DoggoColor.paywallFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 9)
            }

            if showsRestore {
                Button(action: restore) {
                    Text("Restore purchase")
                        .font(DoggoFont.body(12, weight: .bold))
                        .foregroundStyle(DoggoColor.paywallFaint)
                }
                .buttonStyle(.plain)
                .padding(.top, 11)
            }

            if let restoreMessage {
                Text(restoreMessage)
                    .font(DoggoFont.body(11.5))
                    .foregroundStyle(DoggoColor.paywallFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
            }

            Text(footerAttributedString)
                .font(DoggoFont.body(10.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 11)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(DoggoColor.cream)
    }

    /// Matches the prototype's own `showRestoreRow` — only where a purchase
    /// is actually on the table, and never on the free path (nothing to
    /// restore when nothing is being sold).
    private var showsRestore: Bool {
        !canPledgeFree && [.ready, .unreachable, .error].contains(payState)
    }

    @ViewBuilder
    private var ctaPill: some View {
        if canPledgeFree {
            pill(label: isSuccess ? nil : "I'll look out for them",
                 showsCheck: isSuccess,
                 enabled: !isSuccess,
                 action: { Task { await runSuccess() } })
        } else {
            switch payState {
            case .loading:
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: 0xF5D9A6))
                    .frame(height: 56)
                    .shimmer(RoundedRectangle(cornerRadius: 28), duration: 1.3)

            case .unreachable:
                pill(label: "\u{21BB} Try loading price again", enabled: true) {
                    Task { await refreshProduct() }
                }

            case .ready:
                pill(label: "Unlock for \(entitlements.product?.displayPrice ?? "\u{2026}") \u{00B7} one-time",
                     enabled: entitlements.product != nil,
                     shimmering: true,
                     action: buy)

            case .purchasing:
                pill(label: "One moment\u{2026}", enabled: false, spinner: true, action: {})

            case .askPending:
                pill(label: "Waiting for approval\u{2026}", enabled: false, dimmed: true, action: {})

            case .error:
                pill(label: "Try again", enabled: true, action: buy)

            case .success:
                pill(label: nil, showsCheck: true, enabled: false, action: {})
            }
        }
    }

    private func pill(
        label: String?,
        showsCheck: Bool = false,
        enabled: Bool,
        shimmering: Bool = false,
        spinner: Bool = false,
        dimmed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if spinner { ProgressView().tint(.white) }
                if showsCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                } else if let label {
                    Text(label)
                        .font(DoggoFont.display(16, weight: .bold))
                        .kerning(0.2)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(DoggoColor.marigold, in: RoundedRectangle(cornerRadius: 28))
            .opacity(dimmed ? 0.88 : 1)
            .shadow(color: enabled ? DoggoColor.marigold.opacity(0.42) : .clear, radius: 11, y: 9)
        }
        .buttonStyle(ScalePressButtonStyle())
        .disabled(!enabled)
        .modifier(ConditionalShimmer(active: shimmering && !reduceMotion))
    }

    // MARK: - Ceremony

    /// The prototype's entrance timeline: ribbon draws on at 0.5s over
    /// 0.55s, the knot pops at 1.0s, the headline fades up at 0.5s and the
    /// rows follow from 1.1s at 60ms apart. The product load races this
    /// rather than gating it — there's a dedicated skeleton CTA state
    /// precisely so a slow store never stalls the ceremony.
    private func runEntrance() async {
        async let productLoad: Void = refreshProduct()

        if reduceMotion {
            ribbonProgress = 1
            knotScale = 1
            headlineIn = true
            rowsIn = true
        } else {
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { headlineIn = true }
            withAnimation(.timingCurve(0.3, 0.8, 0.4, 1, duration: 0.55).delay(0.5)) {
                ribbonProgress = 1
            }
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.4)) { knotScale = 1 }
            knotHaptic.toggle()
            try? await Task.sleep(for: .seconds(0.1))
            rowsIn = true
        }

        await productLoad
    }

    /// Guarded on both sides of its `await`: the free path can reach
    /// `.success` (and start dismissing) before an in-flight product lookup
    /// returns, and without these the late result would knock the ceremony
    /// back to a live CTA.
    private func refreshProduct() async {
        guard !isSuccess else { return }
        payState = .loading
        await entitlements.loadProductIfNeeded()
        guard !isSuccess else { return }
        payState = entitlements.product != nil ? .ready : .unreachable
    }

    private func buy() {
        payState = .purchasing
        errorMessage = nil
        restoreMessage = nil
        Task {
            do {
                switch try await entitlements.purchase() {
                case .unlocked:
                    await runSuccess()
                case .pending:
                    payState = .askPending
                case .cancelled:
                    payState = .ready
                }
            } catch {
                payState = .error
                errorMessage = "The App Store didn't go through. Nothing was charged \u{2014} try again in a moment."
            }
        }
    }

    private func restore() {
        errorMessage = nil
        restoreMessage = "Checking your Apple Account\u{2026}"
        Task {
            await entitlements.restore()
            if entitlements.isUnlocked {
                restoreMessage = nil
                await runSuccess()
            } else {
                let message = "No previous purchase found on this Apple Account."
                restoreMessage = message
                try? await Task.sleep(for: .seconds(3.2))
                if restoreMessage == message { restoreMessage = nil }
            }
        }
    }

    /// Burst, ribbon flash, tag pop and headline swap all start together,
    /// hold 1.7s, then the pledge lands and the sheet leaves. Shared by the
    /// free CTA, a completed purchase, and a successful restore.
    private func runSuccess() async {
        withAnimation(.easeInOut(duration: 0.3)) { payState = .success }
        successHaptic.toggle()

        if reduceMotion {
            showGuardianTag = true
        } else {
            burstID += 1
            withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.5)) { showGuardianTag = true }
            withAnimation(.easeOut(duration: 0.3)) { ribbonFlash = true }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeIn(duration: 0.3)) { ribbonFlash = false }
            }
        }

        try? await Task.sleep(for: .seconds(1.7))
        pledge()
    }

    // MARK: - Content

    fileprivate struct Benefit {
        let icon: String
        let iconColor: Color
        /// nil = the outlined treatment the first row uses.
        let tileFill: Color?
        /// Each symbol animates in a way that means something for its own
        /// row rather than all four sharing one generic effect.
        let effect: BenefitEffect
        let title: String
        let detail: String
    }

    /// SF Symbol effects are distinct concrete types, so they can't sit in a
    /// single stored property — this enum picks between them at the one
    /// place they're applied.
    fileprivate enum BenefitEffect {
        case bounceUp, wiggle, bounceDown, wiggleLeft
    }

    // Copy and tile colors verbatim from the prototype.
    fileprivate static let benefits = [
        Benefit(icon: "doc.text", iconColor: DoggoColor.provEstFg, tileFill: nil,
                effect: .bounceUp,
                title: "Their whole story, one card",
                detail: "a living dossier with vitals, quirks, and every vet record you save"),
        Benefit(icon: "bell", iconColor: DoggoColor.iconBell, tileFill: DoggoColor.sage,
                effect: .wiggle,        // a bell that rings
                title: "Never miss a dose",
                detail: "medication schedules with real reminders, and one Today\u{2019}s Care list across every dog"),
        Benefit(icon: "printer", iconColor: DoggoColor.iconPrinter, tileFill: DoggoColor.sky,
                effect: .bounceDown,    // a page feeding out
                title: "Ready for any vet",
                detail: "a printable Shelter Pass and their nearest clinic, one tap away"),
        Benefit(icon: "arrow.left.arrow.right", iconColor: DoggoColor.iconHandover, tileFill: DoggoColor.lavender,
                effect: .wiggleLeft,    // something passing hands
                title: "A promise that can travel",
                detail: "hand their whole dossier to a new guardian if life ever changes"),
    ]

    private static let everythingIncluded = [
        "Living dossier \u{2014} vitals, sterilization status, dietary notes, behavioral quirks",
        "One-tap care logs \u{2014} fed, medicated, injury check, vaccinated, with a timeline",
        "Medication schedules with real reminders",
        "Medical records vault \u{2014} vet documents & photos, stored privately",
        "Today\u{2019}s Care \u{2014} every dose due, across every dog",
        "Printable Shelter Pass \u{2014} one page, vet-readable",
        "Assigned clinic \u{2014} nearest vet, searchable/changeable",
        "Guardian Handover \u{2014} pass the whole dossier to a new guardian",
    ]

    /// Only the middle phrase is marigold, underlined and tappable — the
    /// surrounding words stay muted, which a single `Link`-wrapped `Text`
    /// can't express.
    private var footerAttributedString: AttributedString {
        var lead = AttributedString("Want it official? ")
        lead.foregroundColor = DoggoColor.paywallFainter

        var link = AttributedString("Here's how to register as a recognized caretaker")
        link.foregroundColor = DoggoColor.marigoldDark
        link.underlineStyle = .single
        link.link = URL(string: "https://awbi.gov.in/")

        var tail = AttributedString(" with the AWBI Colony Caretaker programme.")
        tail.foregroundColor = DoggoColor.paywallFainter

        return lead + link + tail
    }

    // MARK: - Pledge

    private func pledge() {
        dog.isWard = true
        dog.pledgedAt = .now
        dismiss()
        onPledge()
        assignNearestClinic()
    }

    /// Fires after the pledge UX has already completed (dismiss + toast) so
    /// a slow/offline search never blocks the pledge itself. If it fails or
    /// finds nothing, clinic fields simply stay nil — GuardianDossierView
    /// already renders "None nearby yet" and hides the call row for that
    /// case, so no extra handling is needed here.
    private func assignNearestClinic() {
        let center = CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)
        guard center.latitude != 0 || center.longitude != 0 else { return }
        Task { @MainActor in
            guard let nearest = try? await LiveCareDirectory()
                .places(category: .vet, around: center, radiusKm: 10).first else { return }
            dog.assignedClinicName = nearest.name
            dog.assignedClinicPhone = nearest.phoneNumber
            dog.assignedClinicAddress = nearest.address
            dog.assignedClinicDistanceMeters = nearest.distanceMeters
            dog.assignedClinicLatitude = nearest.coordinate.latitude
            dog.assignedClinicLongitude = nearest.coordinate.longitude
        }
    }
}

/// A benefit row's SF Symbol, animating continuously once its row has
/// landed. Each one repeats on the same ~3.2s period but is started a beat
/// apart from its neighbours, so they stay permanently out of phase — the
/// row of tiles always has something moving in it without the four ever
/// twitching in unison, which is what makes an always-on effect read as
/// fidgety rather than alive.
private struct BenefitSymbol: View {
    let benefit: GuardianPledgeSheet.Benefit
    let index: Int
    let animates: Bool

    /// Flipped once, after this row's own fade-up, and then left on.
    @State private var running = false

    private static let period: Double = 3.2
    private var startDelay: Double { 1.1 + Double(index) * (Self.period / 4) }

    var body: some View {
        symbol
            .task {
                guard animates else { return }
                try? await Task.sleep(for: .seconds(startDelay))
                running = true
            }
    }

    @ViewBuilder
    private var symbol: some View {
        let base = Image(systemName: benefit.icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(benefit.iconColor)
        let options = SymbolEffectOptions.repeat(.periodic(delay: Self.period))

        switch benefit.effect {
        case .bounceUp:
            base.symbolEffect(.bounce.up, options: options, isActive: running)
        case .wiggle:
            base.symbolEffect(.wiggle, options: options, isActive: running)
        case .bounceDown:
            base.symbolEffect(.bounce.down, options: options, isActive: running)
        case .wiggleLeft:
            base.symbolEffect(.wiggle.left, options: options, isActive: running)
        }
    }
}

/// The tile sheen's single pass, mapped off a 0...1 cycle position:
/// invisible until 8%, full at 11%, gone again by 22%, with the gradient
/// travelling left-to-right across that window.
private struct TileSheen: View {
    let progress: Double

    var body: some View {
        let opacity: Double = {
            switch progress {
            case ..<0.08: return 0
            case ..<0.11: return (progress - 0.08) / 0.03
            case ..<0.22: return 1 - (progress - 0.11) / 0.11
            default: return 0
            }
        }()
        let travel = (progress - 0.08) / 0.14   // -> 0...1 across the visible window

        LinearGradient(
            colors: [.clear, .white.opacity(0.6), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 20)
        .rotationEffect(.degrees(20))
        .offset(x: (travel * 60) - 30)
        .opacity(max(0, opacity))
    }
}

/// Applies the CTA shimmer only when it's wanted — `.modifier` keeps the
/// call site a single expression instead of branching the whole button.
private struct ConditionalShimmer: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.shimmer(RoundedRectangle(cornerRadius: 28), duration: 4)
        } else {
            content
        }
    }
}
