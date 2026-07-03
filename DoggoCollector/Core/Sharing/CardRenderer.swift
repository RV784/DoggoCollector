//
//  CardRenderer.swift
//  DoggoCollector
//

import SwiftUI

@MainActor
enum CardRenderer {
    /// Rasterizes any SwiftUI view (a `DoggoCardView`, typically) into a
    /// shareable image at the device's display scale.
    static func renderImage<V: View>(_ view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
