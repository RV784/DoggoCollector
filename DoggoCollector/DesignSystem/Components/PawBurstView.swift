//
//  PawBurstView.swift
//  DoggoCollector
//
//  The Guardian paywall's success burst (decision #25) — 16 particles
//  (every third a paw print, the rest dots) flying out from the CTA and
//  falling away.
//
//  This reproduces the design prototype's `particles()` math EXACTLY rather
//  than approximating it with emitter physics: per-particle angle, distance,
//  the 0.7 vertical squash, the +46pt gravity drop baked into the endpoint,
//  the 0.35 end scale, the 17ms-per-particle stagger, and the opacity hold
//  to 55% of the flight. An earlier pass used a `CAEmitterLayer` with
//  hand-tuned velocity/emissionRange/yAcceleration, which is the more
//  "native particle system" answer but cannot land the prototype's
//  deterministic choreography — and the choreography IS the design here.
//  `KeyframeAnimator` drives the same Core Animation machinery underneath
//  while keeping the keyframes literal and readable.
//

import SwiftUI

struct PawBurstView: View {
    /// Increment to fire one burst. The particle layer only exists while
    /// this is > 0, so nothing animates on first appearance — and each new
    /// value re-identifies the layer, which restarts the keyframes cleanly
    /// (no stale-particle replay of the kind a long-lived emitter can show).
    var burstID: Int

    var body: some View {
        ZStack {
            if burstID > 0 {
                ForEach(0..<Self.count, id: \.self) { i in
                    particle(index: i)
                }
                .id(burstID)
            }
        }
        .allowsHitTesting(false)
    }

    private static let count = 16
    private static let palette: [Color] = [DoggoColor.marigold, DoggoColor.sky, DoggoColor.sage]

    /// Verbatim from the prototype: angle sweeps a full turn with a small
    /// alternating jitter, distance cycles 68/83/98/113/128, and the
    /// vertical component is squashed to 0.7 and lifted 28pt so the spray
    /// reads as going up-and-out before gravity takes it.
    private static func vector(_ i: Int) -> CGSize {
        let angle = (Double(i) / Double(count)) * 2 * .pi + (i % 2 == 0 ? -0.1 : 0.15)
        let distance = 68 + Double(i % 5) * 15
        return CGSize(
            width: cos(angle) * distance,
            height: sin(angle) * distance * 0.7 - 28
        )
    }

    @ViewBuilder
    private func particle(index i: Int) -> some View {
        let isPaw = i % 3 == 0
        let color = Self.palette[i % Self.palette.count]
        let target = Self.vector(i)

        KeyframeAnimator(
            initialValue: BurstFrame(),
            trigger: burstID
        ) { frame in
            Group {
                if isPaw {
                    PawPrint()
                        .fill(color)
                        // The prototype scales its paw builder by 0.4 off a
                        // 30x28 base; folded into the frame directly here.
                        .frame(width: 30 * 0.4, height: 28 * 0.4)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: CGFloat(6 + i % 4), height: CGFloat(6 + i % 4))
                }
            }
            .scaleEffect(frame.scale)
            .opacity(frame.opacity)
            .offset(x: frame.offset.width, y: frame.offset.height)
        } keyframes: { _ in
            KeyframeTrack(\BurstFrame.offset) {
                // Straight-line flight with the gravity drop folded into
                // the endpoint, exactly as the prototype's burstFly does —
                // the easing curve, not a parabola, is what shapes it.
                CubicKeyframe(
                    CGSize(width: target.width, height: target.height + 46),
                    duration: 1.1,
                    startVelocity: .zero,
                    endVelocity: .zero
                )
            }
            KeyframeTrack(\BurstFrame.scale) {
                CubicKeyframe(0.35, duration: 1.1)
            }
            KeyframeTrack(\BurstFrame.opacity) {
                LinearKeyframe(1, duration: 1.1 * 0.55)
                LinearKeyframe(0, duration: 1.1 * 0.45)
            }
        }
        // 17ms per particle, so the spray unspools rather than popping.
        .animation(nil, value: burstID)
        .transition(.identity)
        .modifier(StaggerModifier(delay: Double(i) * 0.017))
    }
}

private struct BurstFrame {
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var opacity: Double = 1
}

/// Holds a particle invisible until its turn comes up. `KeyframeAnimator`
/// starts as soon as it appears, so the stagger has to gate appearance
/// rather than delay the animation itself.
private struct StaggerModifier: ViewModifier {
    let delay: Double
    @State private var armed = false

    func body(content: Content) -> some View {
        Group {
            if armed { content } else { Color.clear.frame(width: 1, height: 1) }
        }
        .task {
            try? await Task.sleep(for: .seconds(delay))
            armed = true
        }
    }
}

/// The prototype's `paw()` builder: a pad plus four toes, in its own
/// 30x28 space.
private struct PawPrint: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30, sy = rect.height / 28
        var path = Path()
        // Pad — bottom center, 18x14.
        path.addEllipse(in: CGRect(x: 6 * sx, y: 14 * sy, width: 18 * sx, height: 14 * sy))
        // Toes — outer pair sit 6 down, inner pair at the top.
        path.addEllipse(in: CGRect(x: 1 * sx, y: 6 * sy, width: 7 * sx, height: 9 * sy))
        path.addEllipse(in: CGRect(x: 9 * sx, y: 0, width: 7 * sx, height: 10 * sy))
        path.addEllipse(in: CGRect(x: 14 * sx, y: 0, width: 7 * sx, height: 10 * sy))
        path.addEllipse(in: CGRect(x: 22 * sx, y: 6 * sy, width: 7 * sx, height: 9 * sy))
        return path
    }
}
