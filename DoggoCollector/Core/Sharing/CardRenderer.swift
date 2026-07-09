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

    /// Rasterizes a view straight into a one-page PDF at `url` (the Shelter
    /// Pass's printable content, typically).
    @discardableResult
    static func renderPDF<V: View>(_ view: V, size: CGSize, to url: URL) -> Bool {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        var done = false
        renderer.render { rSize, render in
            var box = CGRect(origin: .zero, size: rSize)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            render(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            done = true
        }
        return done
    }
}
