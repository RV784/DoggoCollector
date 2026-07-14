//
//  CardDetailView.swift
//  DoggoCollector
//

import SwiftUI

private enum DetailTab: Hashable {
    case sniff, dossier
}

struct CardDetailView: View {
    @Bindable var dog: CaughtDog

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showEditBreed = false
    @State private var editBreedText = ""
    @State private var showPledgeSheet = false
    @State private var showLogSheet = false
    @State private var showShelterPass = false
    @State private var showHandoverOffer = false
    @State private var toastMessage: String?
    @State private var detailTab: DetailTab = .dossier

    private var serialText: String {
        "#" + String(format: "%03d", dog.serialNumber)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DoggoSpacing.lg) {
                        DoggoCardView(
                            image: dog.imageData.flatMap(UIImage.init),
                            name: dog.name,
                            breedLabel: dog.breedLabel,
                            serialNumber: dog.serialNumber,
                            traits: dog.traits,
                            placeholderSeed: dog.id.hashValue
                        )

                        Text("\(serialText) in your pack \u{00B7} caught at \(dog.locationLabel)")
                            .font(DoggoTextStyle.caption)
                            .foregroundStyle(DoggoColor.inkMuted)

                        HStack(spacing: DoggoSpacing.lg) {
                            Button {
                                renameText = dog.name
                                showRename = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                                    .font(DoggoTextStyle.caption)
                                    .foregroundStyle(DoggoColor.marigold)
                            }
                            .buttonStyle(.plain)

                            Button {
                                editBreedText = dog.breedLabel
                                showEditBreed = true
                            } label: {
                                Label("Edit breed", systemImage: "pencil")
                                    .font(DoggoTextStyle.caption)
                                    .foregroundStyle(DoggoColor.marigold)
                            }
                            .buttonStyle(.plain)
                        }

                        if !dog.isWard {
                            pledgeBanner
                        }

                        if dog.isWard {
                            SegmentedTabs(options: [(.sniff, "Scout's Sniff"), (.dossier, "Guardian Dossier")], selection: $detailTab)
                        }

                        if !dog.isWard || detailTab == .sniff {
                            InsightPanelView(dog: dog)
                        } else {
                            GuardianDossierView(dog: dog) { message in
                                toastMessage = message
                            }
                        }
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.top, DoggoSpacing.lg)
                    .padding(.bottom, 100)
                }
            }

            bottomCTA
                .padding(DoggoSpacing.lg)
        }
        .toast(message: $toastMessage)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                circleButton("chevron.left", tint: DoggoColor.ink) {
                    dismiss()
                }
            }
            if dog.isWard {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                circleButton(dog.isFavorite ? "heart.fill" : "heart", tint: DoggoColor.heartPink) {
                    dog.isFavorite.toggle()
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareView(dog: dog)
        }
        .sheet(isPresented: $showPledgeSheet) {
            GuardianPledgeSheet(dog: dog) {
                toastMessage = "You're now \(dog.name)'s Guardian \u{2713}"
                detailTab = .dossier
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogInteractionSheet(dog: dog) { type in
                toastMessage = "\(type.title) logged \u{2713}"
            }
        }
        .fullScreenCover(isPresented: $showShelterPass) {
            ShelterPassView(dog: dog)
        }
        .sheet(isPresented: $showHandoverOffer) {
            HandoverOfferSheet(dog: dog)
        }
        .alert("Rename doggo", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit breed", isPresented: $showEditBreed) {
            TextField("Breed", text: $editBreedText)
            Button("Save") {
                let trimmed = editBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.setUserEditedBreed(trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var bottomCTA: some View {
        if dog.isWard && detailTab == .dossier {
            HStack(spacing: DoggoSpacing.md) {
                PillButton(title: "Log Interaction", systemImage: "checkmark.circle.fill") {
                    showLogSheet = true
                }
                Button {
                    showShelterPass = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DoggoColor.marigold)
                        .glassCircleChrome(size: 56)
                }
                .buttonStyle(.plain)
            }
        } else {
            PillButton(title: "Share this doggo", systemImage: "square.and.arrow.up") {
                showShare = true
            }
        }
    }

    private var pledgeBanner: some View {
        Button {
            showPledgeSheet = true
        } label: {
            HStack(spacing: DoggoSpacing.md) {
                ScoutMascot(expression: .happy, size: 44)
                VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                    Text("Does \(dog.name) live in your neighborhood?")
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(DoggoColor.ink)
                    // A compact filled capsule, not full-width — the
                    // full-width marigold pill language belongs to the
                    // screen's primary CTA ("Share this doggo" below), so
                    // this reads as "secondary but definitely a button"
                    // rather than competing with it.
                    HStack(spacing: 4) {
                        Text("Become their Guardian")
                        Image(systemName: "arrow.right")
                    }
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DoggoSpacing.md)
                    .padding(.vertical, DoggoSpacing.xs)
                    .glassEffect(.clear)
                    .background(DoggoColor.marigoldContrast, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(DoggoSpacing.lg)
            .frame(maxWidth: .infinity)
            // Soft cream card with a border — matching the design prototype
            // (a user-supplied screenshot) and the app's existing "Scout
            // says something" info-card style (see CareView.scoutBanner),
            // not a bold CTA color — the "Share this doggo" button below
            // already owns marigold. A subtle elevation shadow separates
            // this specific card from that flat info-banner styling, since
            // it's the one thing here that's actually tappable.
            .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DoggoRadius.card)
                    .stroke(DoggoColor.statusAttnBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    @ViewBuilder
    private var overflowMenu: some View {
        if dog.wardStatus == .active {
            Menu {
                Button("Hand over guardianship\u{2026}", systemImage: "arrow.triangle.2.circlepath") {
                    showHandoverOffer = true
                }
                // Only once an invite has actually been created — the sender
                // has to confirm this manually (CKShare doesn't notify the
                // sender when a recipient accepts; there's no subscription
                // built for that in this pass, see decision #18).
                if dog.handoverOfferURLString != nil {
                    Button("Mark as handed over", systemImage: "checkmark.circle") {
                        archiveWard(as: .handedOver)
                    }
                }
                Divider()
                Button("Adopted", systemImage: "heart.fill") { archiveWard(as: .adopted) }
                Button("Passed away", systemImage: "leaf.fill") { archiveWard(as: .passed) }
                Button("Lost contact", systemImage: "questionmark.circle") { archiveWard(as: .lostContact) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DoggoColor.ink)
            }
        }
    }

    private func archiveWard(as status: WardStatus) {
        dog.wardStatus = status
        MedicationReminder.cancelAll(for: dog)
        toastMessage = status.archiveToast
    }

    // Deliberately no .glassCircleChrome() here — this is a native
    // ToolbarItem, and the system already gives toolbar item content its
    // own Liquid Glass circle automatically. Wrapping it in our own glass
    // too stacks two glass layers on the same button (the "never nest glass
    // inside glass" rule), which rendered as two overlapping circles.
    private func circleButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(tint)
        }
    }
}
