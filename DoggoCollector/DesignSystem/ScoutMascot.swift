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
}

struct ScoutMascot: View {
    var expression: ScoutExpression = .idle
    var size: CGFloat = 140

    private var fur: Color { Color(hex: 0xCC9966) }
    private var furShade: Color { Color(hex: 0xB37D4B) }
    private var muzzle: Color { Color(hex: 0xFBEEDD) }
    private var earDroop: CGFloat { expression == .sad ? 0.08 : 0 }

    var body: some View {
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

            // Collar
            Capsule()
                .fill(DoggoColor.marigold)
                .frame(width: size * 0.62, height: size * 0.12)
                .offset(y: size * 0.36)
            Circle()
                .fill(DoggoColor.marigoldDark)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(y: size * 0.42)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expression)
    }

    private func ear(flipped: Bool) -> some View {
        Ellipse()
            .fill(furShade)
            .frame(width: size * 0.28, height: size * 0.4)
            .rotationEffect(.degrees(flipped ? 18 : -18))
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
        case .idle:
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
    }
    .padding()
    .background(DoggoColor.cream)
}
