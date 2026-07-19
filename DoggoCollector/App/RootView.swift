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
    @Environment(GameCenterAuthProvider.self) private var authProvider
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
            LandingView(onGetStarted: { introStage = .onboarding })
        case .onboarding:
            OnboardingView(onComplete: {})
        }
    }
}
