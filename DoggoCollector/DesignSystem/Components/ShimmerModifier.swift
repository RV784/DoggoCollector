//
//  ShimmerModifier.swift
//  DoggoCollector
//
//  A translucent gradient sweep across a shape — the Guardian paywall's CTA
//  shimmer and price-loading skeleton (decision #25). Clips to the caller's
//  own shape rather than masking to content, so the underlying view only
//  renders once.
//

import SwiftUI

struct ShimmerModifier<S: Shape>: ViewModifier {
    var shape: S
    var duration: Double = 4

    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .rotationEffect(.degrees(-12))
                    .offset(x: sweep ? geo.size.width * 1.4 : -geo.size.width * 1.4)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
                .animation(.linear(duration: duration).repeatForever(autoreverses: false), value: sweep)
                .onAppear { sweep = true }
            }
        }
    }
}

extension View {
    /// A periodic light sweep across `shape`, clipped to it. No-ops under
    /// Reduce Motion.
    func shimmer<S: Shape>(_ shape: S, duration: Double = 4) -> some View {
        modifier(ShimmerModifier(shape: shape, duration: duration))
    }
}
