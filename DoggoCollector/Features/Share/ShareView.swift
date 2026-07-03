//
//  ShareView.swift
//  DoggoCollector
//
//  Dark "trading card" share sheet: pick a card-back color, preview the
//  exportable card + metadata block, then Share to Story / Save / Copy link.
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
    @Environment(UsernameAuthProvider.self) private var authProvider
    @State private var selectedColorway: CardColorway = .peach
    @State private var isActivitySheetPresented = false
    @State private var renderedImage: UIImage?
    @State private var didCopyLink = false
    @State private var didSavePhoto = false

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
                    textAction(didCopyLink ? "Link copied!" : "Copy link", action: copyLink)
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
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
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
            image: dog.imageData.flatMap(UIImage.init),
            name: dog.name,
            breedLabel: dog.breedLabel,
            serialNumber: dog.serialNumber,
            isCompact: true,
            placeholderSeed: dog.id.hashValue
        )
        .frame(height: 260)
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

            HStack(spacing: DoggoSpacing.sm) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DoggoColor.marigold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DoggoCollector — Catch Real Dogs")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.ink)
                    Text(ShareLinkBuilder.deepLinkURL(for: dog).absoluteString.replacingOccurrences(of: "doggocollector://catch/", with: "doggocollector.app/\(authProvider.currentUsername ?? "scout")/\(dog.name.lowercased())"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DoggoColor.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
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
        var items: [Any] = [ShareLinkBuilder.caption(for: dog), ShareLinkBuilder.deepLinkURL(for: dog)]
        if let renderedImage {
            items.insert(renderedImage, at: 0)
        }
        return items
    }

    private func renderCard() -> UIImage? {
        CardRenderer.renderImage(cardPreview, size: CGSize(width: 340, height: 300))
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

    private func copyLink() {
        UIPasteboard.general.string = ShareLinkBuilder.deepLinkURL(for: dog).absoluteString
        didCopyLink = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            didCopyLink = false
        }
    }
}
