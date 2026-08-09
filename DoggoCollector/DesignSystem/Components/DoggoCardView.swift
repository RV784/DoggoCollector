//
//  DoggoCardView.swift
//  DoggoCollector
//
//  The collectible card — reused across Catch celebration, Card detail, and
//  (in compact form) the Collection grid. Takes plain values rather than the
//  SwiftData model directly so it stays a portable DesignSystem component.
//

import SwiftUI

struct DoggoCardView: View {
    var image: UIImage?
    var name: String
    var breedLabel: String
    var serialNumber: Int
    var traits: [String] = []
    var isCompact: Bool = false
    var placeholderSeed: Int = 0
    /// Guardian Mode only — small marigold "GUARDIAN" corner tag, mirroring
    /// the breed chip on the opposite corner. Kept small so it never
    /// competes with the photo.
    var showsGuardianTag: Bool = false
    /// The dog's whole gallery as a looping playback sequence — live photos
    /// play their movie through, plain photos hold with a slow zoom, and it
    /// crossfades between them for as long as the card is on screen (see
    /// GalleryPlaybackView). Empty means "just show the still `image`".
    ///
    /// The Collection grid gets this too, not just full-size cards: the
    /// camera-revamp plan originally kept the grid still-only, reasoning a
    /// grid of concurrent `AVPlayer`s was the memory/CPU pressure class
    /// decision #19 eliminated. That analogy doesn't hold at this size —
    /// decision #19's problem was ~82MP JPEG decodes (~330MB each), whereas
    /// a tile-tier movie is a 360×360 HEVC clip. Still uncapped, though:
    /// watch real-device scroll smoothness if a user has many live-photo
    /// dogs visible at once.
    var slides: [GallerySlide] = []

    private var serialText: String {
        "#" + String(format: "%03d", serialNumber)
    }

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                fullBody
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.card))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    /// Height of the reflection/caption strip below the square photo.
    private let reflectionHeight: CGFloat = 60

    /// Grid tile: the full square photo sits on top, unobstructed, and the
    /// name/breed ride in a Liquid Glass bar below it. Behind that glass is a
    /// vertically-mirrored copy of the same media (still, live-photo player, or
    /// carousel) — so the glass has real, animating content to refract, like
    /// the dog is standing on glossy glass, without ever covering the photo.
    private var compactBody: some View {
        VStack(spacing: 0) {
            photo
                .allowsHitTesting(false)
                .overlay(alignment: .topTrailing) {
                    if showsGuardianTag { guardianTag }
                }

            // The reflection strip: a *true* mirror of the media — rendered at
            // the same square size as the photo and flipped about the seam, so
            // the pixels at the boundary match and the two read as one
            // continuous surface (no hard line). It sits as the strip's
            // background (so the glass refracts it) while the caption sits as an
            // overlay (so the text stays above the UIKit-backed player layer).
            GeometryReader { geo in
                mediaFill
                    .frame(width: geo.size.width, height: geo.size.width)
                    .scaleEffect(x: 1, y: -1)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
                    .allowsHitTesting(false)
            }
            .frame(height: reflectionHeight)
            .overlay {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(DoggoColor.ink)
                        // A slight self-colored halo so the label stays legible
                        // over whatever media happens to be behind the glass.
                        .shadow(color: DoggoColor.ink.opacity(0.35), radius: 3)
                    Text(breedLabel)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .shadow(color: DoggoColor.inkMuted.opacity(0.35), radius: 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, DoggoSpacing.md)
                .padding(.vertical, DoggoSpacing.sm)
                .glassEffect(.clear, in: Rectangle())
                .background(DoggoColor.chipCream.opacity(0.1))
            }
            .clipped()
        }
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.card))
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .allowsHitTesting(false)
                .overlay(alignment: .topLeading) {
                    TagChip(text: breedLabel)
                        .padding(DoggoSpacing.sm)
                }
                .overlay(alignment: .topTrailing) {
                    if showsGuardianTag { guardianTag }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(name)
                        .font(DoggoTextStyle.displayMedium)
                        .foregroundStyle(DoggoColor.ink)
                        .padding(DoggoSpacing.md)
                }

            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                HStack {
                    Text(breedLabel)
                        .font(DoggoTextStyle.headline)
                        .foregroundStyle(DoggoColor.ink)
                    Spacer()
                    TagChip(text: serialText, prominent: true)
                }
                if !traits.isEmpty {
                    HStack(spacing: DoggoSpacing.xs) {
                        ForEach(traits, id: \.self) { TagChip(text: $0) }
                    }
                }
            }
            .padding(DoggoSpacing.md)
        }
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.card))
    }

    private var guardianTag: some View {
        Text("GUARDIAN")
            .font(DoggoTextStyle.eyebrow)
            .foregroundStyle(.white)
            .padding(.horizontal, DoggoSpacing.sm)
            .padding(.vertical, DoggoSpacing.xs)
            .background(DoggoColor.marigold, in: Capsule())
            .padding(DoggoSpacing.sm)
    }

    /// Square, matching the camera's square viewfinder — every caught dog's
    /// photo is framed 1:1 everywhere it's shown, so what you captured is
    /// what you see on every card, not a different crop per screen. Sized
    /// off whatever width the parent gives (grid tile vs. full card), not a
    /// fixed pixel height, so it stays square at any size.
    @ViewBuilder
    private var photo: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { mediaFill }
            .clipped()
            .contentShape(Rectangle())
    }

    /// The dog's media — still image (or placeholder), with the looping
    /// gallery player layered on top when there's a sequence — scaled to fill
    /// whatever frame it's given. Rendered as the main square photo and again,
    /// mirrored, behind the grid tile's glass caption.
    @ViewBuilder
    private var mediaFill: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PolkaDotPlaceholder(seed: placeholderSeed)
            }

            // A crossfading content layer above the still — never a new
            // geometry peer, so this doesn't touch whatever
            // matchedGeometryEffect chain this card participates in
            // (decision #5). Only worth mounting when there's actually a
            // sequence — a lone plain photo is already drawn by the still layer.
            if slides.count > 1 || slides.first?.isMovie == true {
                GalleryPlaybackView(slides: slides, decodeSize: isCompact ? .tile : .card)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Styled placeholder for photo slots before a real capture exists. Cycles
/// through a few pastel tints (keyed off `seed`) so a grid of placeholders
/// doesn't read as one flat block of blue.
struct PolkaDotPlaceholder: View {
    var seed: Int = 0

    private static let palette: [Color] = [DoggoColor.sky, Color(hex: 0xF7CFC2), Color(hex: 0xF5E3A8), Color(hex: 0xD6CCEF)]

    private var baseColor: Color {
        Self.palette[abs(seed) % Self.palette.count]
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(baseColor.opacity(0.5)))
            let spacing: CGFloat = 18
            let dotRadius: CGFloat = 2
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            DoggoCardView(image: nil, name: "Mochi", breedLabel: "husky", serialNumber: 13, traits: ["Goofball", "Fluffy", "2.6 km"])
            DoggoCardView(image: nil, name: "Mochi", breedLabel: "husky", serialNumber: 13, isCompact: true)
                .frame(width: 170)
        }
        .padding()
    }
    .background(DoggoColor.cream)
}
