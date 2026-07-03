//
//  LaunchView.swift
//  DoggoCollector
//

import SwiftUI

struct LaunchView: View {
    var onFinished: () -> Void

    @State private var scoutScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            DoggoColor.launchGradient
                .ignoresSafeArea()

            VStack(spacing: DoggoSpacing.lg) {
                ScoutMascot(expression: .idle, size: 140)
                    .scaleEffect(scoutScale)

                VStack(spacing: DoggoSpacing.xs) {
                    Text("DoggoCollector")
                        .font(DoggoTextStyle.displayMedium)
                        .foregroundStyle(.white)
                    Text("catch every good dog")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scoutScale = 1
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                textOpacity = 1
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            onFinished()
        }
    }
}

#Preview {
    LaunchView(onFinished: {})
}
