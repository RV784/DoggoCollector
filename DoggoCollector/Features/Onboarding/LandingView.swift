//
//  LandingView.swift
//  DoggoCollector
//

import SwiftUI

// No "I already have a pack" restore link: it used to lead to the same
// onboarding as "Get started" (Phase 1 has no accounts to restore), which
// read as a broken promise. With CloudKit private sync (decision #18) an
// existing pack restores automatically via the device's iCloud account —
// no button needed. A real sign-in entry point returns with Phase 2 auth.
struct LandingView: View {
    var onGetStarted: () -> Void

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

                PillButton(title: "Get started", action: onGetStarted)
            }
            .padding(DoggoSpacing.xl)
        }
    }
}

#Preview {
    LandingView(onGetStarted: {})
}
