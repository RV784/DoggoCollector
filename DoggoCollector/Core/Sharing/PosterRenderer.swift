//
//  PosterRenderer.swift
//  DoggoCollector
//
//  Rasterizes a PosterView into the shareable image. The poster is composed as
//  a rounded card on a filled 9:16 canvas (its own ground colour), so it fills
//  a WhatsApp status / Instagram story cleanly with intentional rounded corners
//  regardless of how the app handles image transparency (no reliance on alpha).
//  Rendered at 3× → a crisp 1620×2880 export (the design is vector, and the
//  photos have enough source resolution to supersample).
//

import SwiftUI

@MainActor
enum PosterRenderer {
    /// The shareable 9:16 image: the poster as a rounded card on a filled ground,
    /// at 3× (1620×2880 — the WhatsApp status / Instagram story target).
    static func render(_ model: PosterRenderModel) -> UIImage? {
        let W = PosterView.width          // 540 (authored)
        let H = PosterView.height         // 960
        let margin: CGFloat = 22          // small inset so the card floats on the canvas
        let cardW = W - margin * 2
        let cardH = cardW * (H / W)       // keep the poster's exact 9:16 — no distortion
        let corner: CGFloat = 42

        let content = ZStack {
            // Filled 9:16 canvas — the poster's own ground, subtly deepened at the
            // edges so the card reads as a distinct card, not just cut corners.
            Rectangle().fill(model.accent.groundGradient)
            RadialGradient(colors: [.clear, model.accent.deep.opacity(0.10)],
                           center: .center, startRadius: 260, endRadius: 560)

            // The poster, scaled down to the card size, rounded, with a soft lift.
            PosterView(model: model)
                .frame(width: W, height: H)
                .scaleEffect(cardW / W)
                .frame(width: cardW, height: cardH)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .shadow(color: model.accent.deep.opacity(0.32), radius: 24, y: 14)
        }
        .frame(width: W, height: H)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
