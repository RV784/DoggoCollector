//
//  EmptyStateView.swift
//  DoggoCollector
//
//  "No dogs caught yet" should invite action, not read as a dead end. The
//  actual catch action lives in the persistent bottom CTA (see
//  CollectionView) so there's only ever one dominant action on screen.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: DoggoSpacing.lg) {
            ScoutMascot(expression: .sad, size: 110)
                .opacity(0.7)
                .floatingIdle()

            VStack(spacing: DoggoSpacing.xs) {
                Text("No dogs caught yet")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                Text("Your first good boy is out there somewhere.\nGo find them.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DoggoSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView()
        .background(DoggoColor.cream)
}
