//
//  ProfileView.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UsernameAuthProvider.self) private var authProvider
    @Query private var catches: [CaughtDog]

    private let mechanic = PackCollectorMechanic()

    var body: some View {
        ZStack {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: DoggoSpacing.xl) {
                topBar

                ScoutMascot(expression: .idle, size: 100)

                Text(authProvider.currentUsername ?? "friend")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)

                HStack(spacing: DoggoSpacing.sm) {
                    ForEach(mechanic.stats(for: catches)) { stat in
                        StatChip(text: stat.label, isActive: stat.isPrimary)
                    }
                }

                NavigationLink(value: SettingsDestination()) {
                    HStack {
                        Label("Settings", systemImage: "gearshape.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                    .padding(DoggoSpacing.lg)
                    .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
                }

                Spacer()
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SettingsDestination.self) { _ in SettingsView() }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.ink)
                    .glassCircleChrome(size: 44)
            }
            Spacer()
        }
    }
}

private struct SettingsDestination: Hashable {}
