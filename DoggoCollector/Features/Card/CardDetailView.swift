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
    @State private var showPledgeSheet = false
    @State private var showLogSheet = false
    @State private var showShelterPass = false
    @State private var toastMessage: String?
    @State private var detailTab: DetailTab = .dossier

    private var serialText: String {
        "#" + String(format: "%03d", dog.serialNumber)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(DoggoSpacing.lg)

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

                        Button {
                            renameText = dog.name
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                                .font(DoggoTextStyle.caption)
                                .foregroundStyle(DoggoColor.marigold)
                        }
                        .buttonStyle(.plain)

                        if !dog.isWard {
                            pledgeBanner
                        }

                        if dog.isWard {
                            SegmentedTabs(options: [(.sniff, "Scout's Sniff"), (.dossier, "Guardian Dossier")], selection: $detailTab)
                        }

                        if !dog.isWard || detailTab == .sniff {
                            InsightPanelView(dog: dog)
                        } else {
                            GuardianDossierView(dog: dog)
                        }
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.bottom, 100)
                }
            }

            bottomCTA
                .padding(DoggoSpacing.lg)
        }
        .toast(message: $toastMessage)
        .toolbar(.hidden, for: .navigationBar)
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
        .alert("Rename doggo", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.name = trimmed }
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
                        .frame(width: 56, height: 56)
                        .background(DoggoColor.cardWhite, in: Circle())
                }
                .buttonStyle(ScalePressButtonStyle())
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Does \(dog.name) live in your neighborhood?")
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(DoggoColor.ink)
                    Text("Become their Guardian \u{2192}")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(DoggoSpacing.lg)
            .frame(maxWidth: .infinity)
            // Soft cream card with a border — matching the design prototype
            // (a user-supplied screenshot) and the app's existing "Scout
            // says something" info-card style (see CareView.scoutBanner),
            // not a bold CTA color — the "Share this doggo" button below
            // already owns marigold.
            .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DoggoRadius.card)
                    .stroke(DoggoColor.statusAttnBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    private var topBar: some View {
        HStack {
            circleButton("chevron.left", tint: DoggoColor.ink) {
                dismiss()
            }
            Spacer()
            if dog.isWard {
                overflowMenu
            }
            circleButton(dog.isFavorite ? "heart.fill" : "heart", tint: DoggoColor.heartPink) {
                dog.isFavorite.toggle()
            }
        }
    }

    @ViewBuilder
    private var overflowMenu: some View {
        if dog.wardStatus == .active {
            Menu {
                Button("Adopted", systemImage: "heart.fill") { archiveWard(as: .adopted) }
                Button("Passed away", systemImage: "leaf.fill") { archiveWard(as: .passed) }
                Button("Lost contact", systemImage: "questionmark.circle") { archiveWard(as: .lostContact) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
            .padding(.trailing, DoggoSpacing.sm)
        }
    }

    private func archiveWard(as status: WardStatus) {
        dog.wardStatus = status
        toastMessage = status.archiveToast
    }

    private func circleButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(DoggoColor.cardWhite, in: Circle())
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}
