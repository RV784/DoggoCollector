//
//  LandingView.swift
//  DoggoCollector
//

import SwiftUI

struct LandingView: View {
    var onGetStarted: () -> Void
    var onAlreadyHavePack: () -> Void

    var body: some View {
        ZStack {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: DoggoSpacing.xxl) {
                Spacer(minLength: DoggoSpacing.xxl)

                ScoutMascot(expression: .idle, size: 120)
                    .floatingIdle()

                VStack(spacing: DoggoSpacing.md) {
                    Text("Catch every good\ndog you meet.")
                        .font(DoggoTextStyle.displayLarge)
                        .foregroundStyle(DoggoColor.ink)
                        .multilineTextAlignment(.center)

                    Text("Point your camera at a real pup, catch it, and build a pack that's all your own.")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DoggoSpacing.lg)
                }

                Spacer()

                VStack(spacing: DoggoSpacing.md) {
                    PillButton(title: "Get started", action: onGetStarted)
                    TextLinkButton(title: "I already have a pack", action: onAlreadyHavePack)
                }
            }
            .padding(DoggoSpacing.xl)
        }
    }
}

#Preview {
    LandingView(onGetStarted: {}, onAlreadyHavePack: {})
}
