//
//  GalleryHeroView.swift
//  DoggoCollector
//
//  The gallery's dominant top image: the dog's whole collection cycling in
//  place, with the name and item count laid over the bottom — the
//  reference's hero treatment.
//
//  The cycling itself is GalleryPlaybackView's job (live photos play their
//  movie, plain photos hold with a slow zoom), so this view is only the
//  chrome around it. It used to run its own separate crossfade loop, which
//  duplicated that logic and could only cycle stills.
//
//  Reduce Motion and single-photo dogs are handled inside GalleryPlaybackView
//  — a lone plain photo renders static, with nothing to cycle and no empty
//  carousel.
//

import SwiftUI

struct GalleryHeroView: View {
    let dog: CaughtDog
    /// Leading/trailing margin for the name overlay — passed in so it stays
    /// in lockstep with the rest of the gallery screen's shared inset.
    var contentInset: CGFloat = DoggoSpacing.xl

    private var photoCount: Int {
        max(dog.sortedPhotos.count, dog.coverImageData == nil ? 0 : 1)
    }

    var body: some View {
        ZStack {
            DoggoColor.chipCream

            GalleryPlaybackView(slides: dog.gallerySlides(tier: .full), decodeSize: .card)

            LinearGradient(
                colors: [.black.opacity(0.25), .clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(dog.name)
                    .font(DoggoFont.display(40, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(photoCount) \(photoCount == 1 ? "Item" : "Items")")
                        .font(DoggoTextStyle.bodySemibold)
                }
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Same margin as the floating bars above/below it, so the name
            // lines up with the controls rather than sitting closer to the
            // edge than they do.
            .padding(.horizontal, contentInset)
            .padding(.bottom, DoggoSpacing.lg)
        }
        .clipped()
    }
}
