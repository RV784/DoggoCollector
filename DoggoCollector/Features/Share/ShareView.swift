//
//  ShareView.swift
//  DoggoCollector
//
//  Dark "trading card" share sheet: pick a card-back color, preview the
//  exportable card + metadata block, then Share to Story / Save / Share.
//  No link actions: the doggocollector:// deep link had no registered
//  scheme or handler anywhere (a dead string for recipients), and the
//  doggocollector.app display URL was a domain that doesn't exist — both
//  cut (2026-07-17, same honesty principle as decision #13's removed fake
//  open-hours) until the Phase 2 backend gives links somewhere to land.
//

import SwiftUI

private enum CardColorway: CaseIterable, Hashable {
    case marigold, sky, peach, ink

    var color: Color {
        switch self {
        case .marigold: DoggoColor.marigold
        case .sky: DoggoColor.sky
        case .peach: Color(hex: 0xF2A98C)
        case .ink: DoggoColor.ink
        }
    }
}

struct ShareView: View {
    let dog: CaughtDog

    @Environment(\.dismiss) private var dismiss
    @Environment(GameCenterAuthProvider.self) private var authProvider
    @State private var selectedColorway: CardColorway = .peach
    @State private var isActivitySheetPresented = false
    @State private var renderedImage: UIImage?
    @State private var didSavePhoto = false
    @State private var insight: DogInsight?

    private let insightProvider: DogInsightProviding = FoundationModelsInsightProvider()

    private var shareBackground: Color { Color(hex: 0x1C1712) }

    var body: some View {
        VStack(spacing: DoggoSpacing.lg) {
            topBar

            VStack(spacing: DoggoSpacing.xs) {
                Text("Share \(dog.name)")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(.white)
                Text("Pick a card back")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(.white.opacity(0.6))
            }

            colorwayRow

            ScrollView {
                cardPreview
                    .padding(.horizontal, DoggoSpacing.xl)

                metadataBlock
                    .padding(.horizontal, DoggoSpacing.xl)
                    .padding(.top, DoggoSpacing.md)
            }

            VStack(spacing: DoggoSpacing.md) {
                PillButton(title: "Share to Story", systemImage: "camera.fill", action: shareToInstagramStory)
                HStack {
                    textAction(didSavePhoto ? "Saved!" : "Save photo", action: savePhoto)
                    Spacer()
                    textAction("Share") { isActivitySheetPresented = true }
                }
            }
            .padding(.horizontal, DoggoSpacing.xl)
            .padding(.bottom, DoggoSpacing.lg)
        }
        .padding(.top, DoggoSpacing.lg)
        .background(shareBackground.ignoresSafeArea())
        .task(id: selectedColorway) {
            renderedImage = renderCard()
        }
        .task(id: dog.classifiedBreedRaw) {
            insight = await insightProvider.insight(for: dog)
        }
        .sheet(isPresented: $isActivitySheetPresented) {
            ActivityView(activityItems: shareItems)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .glassCircleChrome(size: 36)
            }
        }
        .padding(.horizontal, DoggoSpacing.lg)
    }

    private var colorwayRow: some View {
        HStack(spacing: DoggoSpacing.md) {
            ForEach(CardColorway.allCases, id: \.self) { colorway in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColorway = colorway
                    }
                } label: {
                    Circle()
                        .fill(colorway.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: selectedColorway == colorway ? 2 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardPreview: some View {
        DoggoCardView(
            image: DogPhoto.image(from: dog.imageData, size: .card, cacheKey: dog.id.uuidString),
            name: dog.name,
            breedLabel: dog.breedLabel,
            serialNumber: dog.serialNumber,
            isCompact: true,
            placeholderSeed: dog.id.hashValue
        )
        .padding(DoggoSpacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DoggoRadius.card + 6)
                .stroke(selectedColorway.color, lineWidth: 6)
        )
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            HStack {
                Text("@\(authProvider.currentUsername ?? "scout")")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DoggoSpacing.md)
                    .padding(.vertical, DoggoSpacing.xs)
                    .background(DoggoColor.ink, in: Capsule())
                Spacer()
                Label(dog.locationLabel, systemImage: "mappin")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }

            metadataGrid

            HStack(spacing: DoggoSpacing.sm) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DoggoColor.marigold)
                Text("DoggoCollector — Catch Real Dogs")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.ink)
            }
        }
        .padding(DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: DoggoSpacing.lg, verticalSpacing: DoggoSpacing.sm) {
            GridRow {
                metadataCell(label: "AGE", value: insight?.ageBracket.rawValue ?? "—")
                // Honesty over a static label: once the user has corrected
                // the breed by hand, it's no longer an AI guess (same
                // principle as decision #13's removal of fake open-hours).
                metadataCell(label: dog.breedUserEdited ? "BREED" : "BREED · AI GUESS", value: insight?.breedGuess ?? "—")
            }
            GridRow {
                metadataCell(label: "NEIGHBORHOOD", value: dog.locationLabel)
                metadataCell(label: "FIRST SPOTTED", value: dog.caughtAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private func metadataCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.metadataLabel)
            Text(value)
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private var shareItems: [Any] {
        var items: [Any] = [ShareLinkBuilder.caption(for: dog)]
        if let renderedImage {
            items.insert(renderedImage, at: 0)
        }
        return items
    }

    private func renderCard() -> UIImage? {
        // Height grew once the photo became square (matching the camera
        // viewfinder) instead of the old fixed-260 landscape crop.
        CardRenderer.renderImage(cardPreview, size: CGSize(width: 340, height: 420))
    }

    private func shareToInstagramStory() {
        guard let url = URL(string: "instagram-stories://share"), let imageData = renderedImage?.pngData() else {
            isActivitySheetPresented = true
            return
        }
        let pasteboardItem: [String: Any] = ["com.instagram.sharedSticker.backgroundImage": imageData]
        UIPasteboard.general.setItems([pasteboardItem], options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                isActivitySheetPresented = true
            }
        }
    }

    private func savePhoto() {
        guard let renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(renderedImage, nil, nil, nil)
        didSavePhoto = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            didSavePhoto = false
        }
    }

}
