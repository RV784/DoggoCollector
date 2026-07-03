//
//  RootView.swift
//  DoggoCollector
//

import SwiftUI

private enum IntroStage {
    case launch
    case landing
    case onboarding
}

struct RootView: View {
    @Environment(UsernameAuthProvider.self) private var authProvider
    @State private var introStage: IntroStage = .launch

    var body: some View {
        Group {
            if authProvider.currentUsername != nil {
                CollectionView()
            } else {
                introFlow
            }
        }
    }

    @ViewBuilder
    private var introFlow: some View {
        switch introStage {
        case .launch:
            LaunchView(onFinished: { introStage = .landing })
        case .landing:
            LandingView(
                onGetStarted: { introStage = .onboarding },
                // Phase 1 has no backend to restore an account from, so this
                // leads to the same onboarding step for now. Phase 2 (Sign in
                // with Apple/Google + Firebase) will make this a real
                // sign-in path without touching this call site.
                onAlreadyHavePack: { introStage = .onboarding }
            )
        case .onboarding:
            OnboardingView(onComplete: {})
        }
    }
}
