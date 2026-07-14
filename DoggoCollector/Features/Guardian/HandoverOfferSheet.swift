//
//  HandoverOfferSheet.swift
//  DoggoCollector
//
//  Sender side of Guardian Handover (decision #18) — reached from Card
//  Detail's overflow menu ("Hand over guardianship…", wards only, active
//  only). No real screens exist for this in Claude Design (the medication-
//  tracking plan's own §14 called for design-first sequencing on this UI,
//  but that design pass never happened) — built minimal and functional in
//  the established Sunny Fetch component language instead, same fallback
//  this project has used before when the design tool wasn't reachable.
//  Flag for a design pass later if the user wants this screen polished.
//

import SwiftUI

struct HandoverOfferSheet: View {
    @Bindable var dog: CaughtDog

    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var inviteURL: URL?

    private let provider: HandoverProviding = CloudKitHandoverProvider()

    var body: some View {
        VStack(spacing: DoggoSpacing.xl) {
            ScoutMascot(expression: .idle, size: 100)

            VStack(spacing: DoggoSpacing.sm) {
                Text("Hand over \(dog.name)'s guardianship")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                    .multilineTextAlignment(.center)
                Text("Their full dossier — vitals, care history, medications — travels with the invite. This copies their record; it doesn't keep the two in sync afterward.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .multilineTextAlignment(.center)
            }

            content
        }
        .padding(DoggoSpacing.xl)
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let existing = dog.handoverOfferURLString, let url = URL(string: existing) {
                inviteURL = url
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let inviteURL {
            ShareLink(item: inviteURL) {
                HStack(spacing: DoggoSpacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share invite link")
                }
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DoggoSpacing.lg)
                .background(DoggoColor.marigold, in: Capsule())
            }
        } else if isCreating {
            BouncingDotsView()
        } else if let errorMessage {
            VStack(spacing: DoggoSpacing.md) {
                Text(errorMessage)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.logInjuryFg)
                    .multilineTextAlignment(.center)
                PillButton(title: "Try again", action: createInvite)
            }
        } else {
            PillButton(title: "Create invite link", action: createInvite)
        }
    }

    private func createInvite() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let url = try await provider.offer(dog)
                dog.handoverOfferURLString = url.absoluteString
                inviteURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}
