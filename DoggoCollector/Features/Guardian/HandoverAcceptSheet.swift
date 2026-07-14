//
//  HandoverAcceptSheet.swift
//  DoggoCollector
//
//  Recipient side of Guardian Handover (decision #18) — presented when
//  CloudKitShareCoordinator.pendingMetadata is set (SceneDelegate caught an
//  incoming CKShare-accept tap). Same "no real design for this screen yet"
//  caveat as HandoverOfferSheet.
//

import SwiftUI
import SwiftData
import CloudKit

struct HandoverAcceptSheet: View {
    let metadata: CKShare.Metadata
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isAccepting = false
    @State private var errorMessage: String?
    @State private var acceptedDogName: String?

    private let provider: HandoverProviding = CloudKitHandoverProvider()

    var body: some View {
        VStack(spacing: DoggoSpacing.xl) {
            ScoutMascot(expression: acceptedDogName != nil ? .happy : .idle, size: 120)

            if let acceptedDogName {
                Text("\(acceptedDogName) is now in your Pack")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                    .multilineTextAlignment(.center)
                PillButton(title: "Done", action: onDismiss)
            } else if let errorMessage {
                VStack(spacing: DoggoSpacing.sm) {
                    Text("Couldn't accept this invite")
                        .font(DoggoTextStyle.headline)
                        .foregroundStyle(DoggoColor.ink)
                    Text(errorMessage)
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .multilineTextAlignment(.center)
                }
                PillButton(title: "Close", action: onDismiss)
            } else {
                VStack(spacing: DoggoSpacing.sm) {
                    Text("Someone's handing you guardianship")
                        .font(DoggoTextStyle.displayMedium)
                        .foregroundStyle(DoggoColor.ink)
                        .multilineTextAlignment(.center)
                    Text("Their dossier — vitals, care history, medications — will copy into your Pack.")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .multilineTextAlignment(.center)
                }
                if isAccepting {
                    BouncingDotsView()
                } else {
                    PillButton(title: "Accept", action: accept)
                    TextLinkButton(title: "Not now", color: DoggoColor.inkMuted, action: onDismiss)
                }
            }
        }
        .padding(DoggoSpacing.xl)
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    private func accept() {
        isAccepting = true
        errorMessage = nil
        Task {
            do {
                let acceptance = try await provider.accept(metadata: metadata)
                let dog = try HandoverMaterializer.materialize(acceptance, into: modelContext)
                await MedicationReminder.sweep(dogs: [dog])
                acceptedDogName = dog.name
            } catch {
                errorMessage = error.localizedDescription
            }
            isAccepting = false
        }
    }
}
