//
//  ShelterPassLightField.swift
//  DoggoCollector
//
//  The warm sunlit "light field" behind the paper pass — the redesign's
//  reinterpretation of the brief's "metal": sunlight on paper, not chrome.
//  Six layers, bottom→top (Shelter Pass.dc.html · "LAYER STACK · THE LIGHT
//  FIELD"): warm ground ramp, a drifting MeshGradient bloom, a high sun core,
//  a tilt-parented highlight (CoreMotion), fine paper grain, and a warm floor
//  vignette that keeps the cream pass in contrast at any tilt.
//
//  Accessibility: Reduce Transparency collapses the whole field to one still
//  warm gradient (no mesh/drift/tilt); Reduce Motion keeps the field but holds
//  it still (no drift, no tilt). The pass surface is opaque in every mode —
//  the field never sits behind text.
//

import SwiftUI
import UIKit

struct ShelterPassLightField: View {
    var tilt: TiltProvider

    /// A 3pt dot tile, rendered once and tiled by the GPU — far cheaper than a
    /// full-screen Canvas that would re-run on every tilt frame.
    private static let grainTile: UIImage = {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3))
        return r.image { ctx in
            UIColor(DoggoColor.passGrainInk).withAlphaComponent(0.055).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            // One still warm gradient — no mesh, no drift, no tilt bloom.
            LinearGradient(
                colors: [DoggoColor.passReduceTransp1, DoggoColor.passReduceTransp2],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(paperGrain)
            .ignoresSafeArea()
        } else {
            ZStack {
                warmGround
                meshBloom
                sunCore
                tiltBloom
                paperGrain
                warmFloor
            }
            .ignoresSafeArea()
        }
    }

    // 1 · Warm ground ramp (168°).
    private var warmGround: some View {
        LinearGradient(
            stops: [
                .init(color: DoggoColor.passGround1, location: 0),
                .init(color: DoggoColor.passGround2, location: 0.38),
                .init(color: DoggoColor.passGround3, location: 0.66),
                .init(color: DoggoColor.passGround4, location: 1),
            ],
            startPoint: UnitPoint(x: 0.58, y: 0), endPoint: UnitPoint(x: 0.42, y: 1)
        )
    }

    // 2 · Mesh bloom — four soft light pools that drift like light. Held still
    // under Reduce Motion.
    private var meshBloom: some View {
        Group {
            if reduceMotion {
                mesh(t: 0)
            } else {
                TimelineView(.animation) { ctx in
                    mesh(t: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .opacity(0.9)
    }

    private func mesh(t: TimeInterval) -> some View {
        // Interior points drift on slow sines; corners stay pinned so no gaps.
        let a = CGFloat(sin(t * 0.18)) * 0.05
        let b = CGFloat(cos(t * 0.13)) * 0.05
        let pts: [SIMD2<Float>] = [
            [0, 0], [0.5 + Float(a), 0], [1, 0],
            [0, 0.5 + Float(b)], [0.5 + Float(a * 1.4), 0.46 + Float(b)], [1, 0.5 - Float(b)],
            [0, 1], [0.5 - Float(a), 1], [1, 1],
        ]
        return MeshGradient(
            width: 3, height: 3, points: pts,
            colors: [
                DoggoColor.passGround1, DoggoColor.passPoolMarigold, DoggoColor.passGround2,
                DoggoColor.passPoolPeach, DoggoColor.passGround1, DoggoColor.passPoolSage,
                DoggoColor.passGround3, DoggoColor.passPoolMarigold, DoggoColor.passGround4,
            ]
        )
    }

    // 3 · Sun core — a high, wide white bloom at 6% from the top (the window).
    private var sunCore: some View {
        RadialGradient(
            colors: [.white.opacity(0.9), .clear],
            center: UnitPoint(x: 0.5, y: 0.06),
            startRadius: 0, endRadius: 320
        )
    }

    // 4 · Tilt bloom — a soft highlight parented to device attitude.
    private var tiltBloom: some View {
        let cx = 0.5 + (reduceMotion ? 0 : tilt.x * 0.07)
        let cy = 0.28 + (reduceMotion ? 0 : tilt.y * 0.07)
        return RadialGradient(
            colors: [.white.opacity(0.55), .clear],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0, endRadius: 260
        )
        .blendMode(.softLight)
    }

    // 5 · Paper grain — keeps it reading as light on paper, not glass.
    private var paperGrain: some View {
        Image(uiImage: Self.grainTile)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
    }

    // 6 · Warm floor — low amber vignette so the cream pass holds contrast.
    private var warmFloor: some View {
        RadialGradient(
            colors: [DoggoColor.passFloor.opacity(0.45), .clear],
            center: UnitPoint(x: 0.5, y: 1.08),
            startRadius: 0, endRadius: 520
        )
    }
}
