//
//  PawSeal.swift
//  DoggoCollector
//
//  The pass's signature mark — Scout's paw, pressed into the paper. Screen: a
//  warm cream medallion with an engraved conic starburst, a hairline ring, and
//  an amber paw (embossed feel). Print (`PawSeal.Flat`): the same emblem gone
//  flat — paper-white disc, ink rings, a solid ink paw, no light on it.
//  Shapes only, so it rasterizes cleanly into the PDF.
//

import SwiftUI

/// Scout's paw — four toes over a pad, in a fixed 38×34 box (scaled by parent).
private struct PawGlyph: View {
    var color: Color

    var body: some View {
        ZStack {
            toe(x: 5, y: 11.5, w: 8, h: 11, deg: -22)
            toe(x: 15.25, y: 7, w: 8.5, h: 12, deg: -8)
            toe(x: 25.25, y: 7, w: 8.5, h: 12, deg: 8)
            toe(x: 34, y: 11.5, w: 8, h: 11, deg: 22)
            Ellipse()
                .fill(color)
                .frame(width: 21, height: 16)
                .position(x: 19.5, y: 26)
        }
        .frame(width: 38, height: 34)
    }

    private func toe(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, deg: Double) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: w, height: h)
            .rotationEffect(.degrees(deg))
            .position(x: x, y: y)
    }
}

/// The living (screen) seal.
struct PawSeal: View {
    var size: CGFloat = 82

    var body: some View {
        ZStack {
            // Base medallion — warm cream, embossed.
            Circle()
                .fill(RadialGradient(
                    colors: [DoggoColor.sealCream1, DoggoColor.sealCream2, DoggoColor.sealCream3],
                    center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: size * 0.62))
                .overlay(Circle().stroke(DoggoColor.sealRing, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 8)

            // Engraved conic starburst ring.
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(stops: Self.burstStops(DoggoColor.passGrainInk.opacity(0.18))),
                    center: .center))
                .padding(size * 0.06)
                .mask(Circle().stroke(lineWidth: size * 0.28).padding(size * 0.16))

            Circle()
                .stroke(DoggoColor.sealRing.opacity(0.9), lineWidth: 1)
                .padding(size * 0.12)

            // Inner disc + paw.
            Circle()
                .fill(RadialGradient(
                    colors: [DoggoColor.sealCream1, Color(hex: 0xFBEBD2)],
                    center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.4))
                .padding(size * 0.16)

            PawGlyph(color: DoggoColor.sealPaw)
                .scaleEffect(size / 82 * 0.95)
        }
        .frame(width: size, height: size)
    }

    /// The flat print seal — same emblem, ink on paper-white, no light.
    struct Flat: View {
        var size: CGFloat = 60

        var body: some View {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: 0xFBF3E2), Color(hex: 0xF1E3C6), Color(hex: 0xE6D3AC)],
                        center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: size * 0.6))
                    .overlay(Circle().stroke(DoggoColor.printInk, lineWidth: 1.5))

                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(stops: PawSeal.burstStops(DoggoColor.printInk.opacity(0.5))),
                        center: .center))
                    .padding(size * 0.08)
                    .mask(Circle().stroke(lineWidth: size * 0.30).padding(size * 0.1))

                Circle()
                    .stroke(DoggoColor.printGuilloche, lineWidth: 0.75)
                    .padding(size * 0.15)

                PawGlyph(color: DoggoColor.printInk)
                    .scaleEffect(size / 82 * 0.85)
            }
            .frame(width: size, height: size)
        }
    }

    /// A fine repeating spoke pattern for the engraved ring.
    fileprivate static func burstStops(_ c: Color) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        let spokes = 60
        for i in 0..<spokes {
            let a = Double(i) / Double(spokes)
            let b = (Double(i) + 0.5) / Double(spokes)
            stops.append(.init(color: c, location: a))
            stops.append(.init(color: .clear, location: a + 0.0001))
            stops.append(.init(color: .clear, location: b))
            stops.append(.init(color: c, location: b + 0.0001))
        }
        return stops
    }
}
