//
//  ScoutMascot.swift
//  DoggoCollector
//
//  Scout, the app's mascot, built entirely from primitive SwiftUI shapes so it
//  never needs an image asset and can react (expression) across screens —
//  this mirrors how the mascot was designed: "simple shapes so it ports
//  straight to SwiftUI."
//

import SwiftUI

enum ScoutExpression: Equatable {
    /// Launch, Landing — content, neutral smile.
    case idle
    /// Catch celebration — tongue out, eyes squeezed happy.
    case happy
    /// Empty state — downturned mouth, drooping ears.
    case sad
    /// Card Detail's "Scout's Sniff" loading state — head tilted, one ear
    /// raised, sniff marks near the nose.
    case curious
}

struct ScoutMascot: View {
    var expression: ScoutExpression = .idle
    var size: CGFloat = 140
    /// Guardian Mode only — replaces the plain collar with the guardian
    /// ribbon: a marigold-dark arc slung under the chin, tied with a small
    /// white knot. Geometry is verbatim from the "Guardian Paywall.dc.html"
    /// prototype's own SVG (a 104x102 overlay: `M18,85 Q52,102 86,85`,
    /// 10pt round-capped stroke in #E08E0B, plus a knot circle at (52,100)
    /// r=7, white filled with a 3pt stroke). Drawn outside `headGroup` so
    /// it stays level when the head tilts for `.curious`, same reasoning as
    /// the collar it replaces.
    var wearsGuardianMedal: Bool = false
    /// 0 = undrawn, 1 = fully drawn (default, so every pre-existing call
    /// site is unaffected). The ribbon is a trimmed stroke specifically so
    /// this reproduces the prototype's stroke-dashoffset draw-on.
    var ribbonDrawProgress: CGFloat = 1
    /// The knot's own pop (prototype: scale 0 -> 1.3 -> 1, 0.4s, 1.0s in).
    /// Lives here rather than being positioned by the caller so the knot
    /// can't drift out of register with the arc it ties.
    var ribbonKnotScale: CGFloat = 1

    @State private var curiousOscillate = false

    private var fur: Color { Color(hex: 0xCC9966) }
    private var furShade: Color { Color(hex: 0xB37D4B) }
    private var muzzle: Color { Color(hex: 0xFBEEDD) }
    private var earDroop: CGFloat { expression == .sad ? 0.08 : 0 }

    /// Base -9° tilt for `.curious`, oscillating a further ±2° — the collar
    /// stays level, so only the head group (not the whole mascot) rotates.
    private var headTiltDegrees: Double {
        guard expression == .curious else { return 0 }
        return curiousOscillate ? -11 : -7
    }

    var body: some View {
        ZStack {
            headGroup
                .rotationEffect(.degrees(headTiltDegrees))
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: curiousOscillate)

            // Collar / ribbon — deliberately outside headGroup so it stays
            // level while the head tilts for `.curious`. Guardian mode swaps
            // the plain collar for a diagonal "GUARDIAN" ribbon entirely,
            // matching the design prototype (not a small badge alongside it).
            if wearsGuardianMedal {
                guardianRibbon
            } else {
                Capsule()
                    .fill(DoggoColor.marigold)
                    .frame(width: size * 0.62, height: size * 0.12)
                    .offset(y: size * 0.36)
                Circle()
                    .fill(DoggoColor.marigoldDark)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .offset(y: size * 0.42)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expression)
        .onAppear { curiousOscillate = true }
    }

    /// The guardian ribbon — see `wearsGuardianMedal` for the extracted
    /// geometry this reproduces. Everything is expressed in the prototype's
    /// own 104x102 space and scaled by `u`, so the arc, its stroke weight,
    /// and the knot all stay in proportion at any `size`.
    private var guardianRibbon: some View {
        let u = size / 104
        return ZStack(alignment: .topLeading) {
            RibbonArc()
                .trim(from: 0, to: ribbonDrawProgress)
                .stroke(
                    DoggoColor.marigoldDark,
                    style: StrokeStyle(lineWidth: 10 * u, lineCap: .round)
                )

            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(DoggoColor.marigoldDark, lineWidth: 3 * u))
                .frame(width: 14 * u, height: 14 * u)
                .scaleEffect(ribbonKnotScale)
                .offset(x: 45 * u, y: 93 * u)   // centers a 14u knot on (52,100)
        }
        .frame(width: size, height: size)
    }

    private var headGroup: some View {
        ZStack {
            // Ears
            ear(flipped: false)
                .offset(x: -size * 0.32, y: -size * 0.18 + size * earDroop)
            ear(flipped: true)
                .offset(x: size * 0.32, y: -size * 0.18 + size * earDroop)

            // Head
            Ellipse()
                .fill(fur)
                .frame(width: size * 0.86, height: size * 0.8)

            // Muzzle
            Ellipse()
                .fill(muzzle)
                .frame(width: size * 0.5, height: size * 0.36)
                .offset(y: size * 0.18)

            // Nose
            RoundedRectangle(cornerRadius: size * 0.03)
                .fill(Color(hex: 0x3A2620))
                .frame(width: size * 0.09, height: size * 0.06)
                .offset(y: size * 0.06)

            mouth

            // Eyes
            eyes

            if expression == .curious {
                sniffMarks
            }
        }
    }

    private func ear(flipped: Bool) -> some View {
        Ellipse()
            .fill(furShade)
            .frame(width: size * 0.28, height: size * 0.4)
            .rotationEffect(.degrees(earRotationDegrees(flipped: flipped)))
    }

    /// Normally the ears splay symmetrically outward. For `.curious`, one
    /// ear (the "flipped" one) stands up straighter than the other.
    private func earRotationDegrees(flipped: Bool) -> Double {
        if expression == .curious {
            return flipped ? 4 : -18
        }
        return flipped ? 18 : -18
    }

    @ViewBuilder
    private var sniffMarks: some View {
        ForEach(0..<2, id: \.self) { i in
            Capsule()
                .stroke(Color(hex: 0x3A2620).opacity(0.6), lineWidth: size * 0.012)
                .frame(width: size * 0.09, height: size * 0.02)
                .rotationEffect(.degrees(-25))
                .offset(x: size * (0.17 + Double(i) * 0.06), y: size * (0.02 - Double(i) * 0.035))
        }
    }

    @ViewBuilder
    private var eyes: some View {
        let eyeSize = size * 0.09
        let eyeY = -size * 0.04
        HStack(spacing: size * 0.22) {
            eye(size: eyeSize)
            eye(size: eyeSize)
        }
        .offset(y: eyeY)
    }

    private func eye(size eyeSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x2B2013))
                .frame(width: eyeSize, height: expression == .happy ? eyeSize * 0.4 : eyeSize)
            if expression != .happy {
                Circle()
                    .fill(.white)
                    .frame(width: eyeSize * 0.32, height: eyeSize * 0.32)
                    .offset(x: -eyeSize * 0.2, y: -eyeSize * 0.2)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch expression {
        case .idle, .curious:
            Capsule()
                .stroke(Color(hex: 0x3A2620), lineWidth: size * 0.015)
                .frame(width: size * 0.16, height: size * 0.08)
                .offset(y: size * 0.14)
        case .happy:
            VStack(spacing: -size * 0.02) {
                Capsule()
                    .fill(Color(hex: 0x3A2620))
                    .frame(width: size * 0.2, height: size * 0.1)
                Capsule()
                    .fill(DoggoColor.heartPink)
                    .frame(width: size * 0.11, height: size * 0.14)
            }
            .offset(y: size * 0.16)
        case .sad:
            Capsule()
                .stroke(Color(hex: 0x3A2620), lineWidth: size * 0.015)
                .frame(width: size * 0.14, height: size * 0.06)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.15)
        }
    }
}

/// The ribbon's arc, in the prototype's 104x102 coordinate space:
/// `M18,85 Q52,102 86,85` — a shallow quadratic slung under the chin.
private struct RibbonArc: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 104, sy = rect.height / 102
        var path = Path()
        path.move(to: CGPoint(x: 18 * sx, y: 85 * sy))
        path.addQuadCurve(
            to: CGPoint(x: 86 * sx, y: 85 * sy),
            control: CGPoint(x: 52 * sx, y: 102 * sy)
        )
        return path
    }
}

/// A gentle continuous up/down drift for idle mascot moments (Landing,
/// Empty state) — the design calls for these to feel alive, not static.
private struct FloatingModifier: ViewModifier {
    var distance: CGFloat = 8
    var duration: Double = 2.2
    @State private var isUp = false

    func body(content: Content) -> some View {
        content
            .offset(y: isUp ? -distance : distance)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: isUp)
            .onAppear { isUp = true }
    }
}

extension View {
    func floatingIdle(distance: CGFloat = 8, duration: Double = 2.2) -> some View {
        modifier(FloatingModifier(distance: distance, duration: duration))
    }
}

#Preview {
    HStack(spacing: 20) {
        ScoutMascot(expression: .idle)
        ScoutMascot(expression: .happy)
        ScoutMascot(expression: .sad)
        ScoutMascot(expression: .curious)
    }
    .padding()
    .background(DoggoColor.cream)
}
