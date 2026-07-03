//
//  OnboardingView.swift
//  DoggoCollector
//
//  Username only, no email/password — should feel like the start of
//  something fun, not a form.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(UsernameAuthProvider.self) private var authProvider
    var onComplete: () -> Void

    @State private var username: String = ""
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: DoggoSpacing.xxl) {
                Spacer(minLength: DoggoSpacing.xl)

                ScoutMascot(expression: .idle, size: 120)
                    .floatingIdle()

                VStack(spacing: DoggoSpacing.sm) {
                    Text("What should we\ncall you?")
                        .font(DoggoTextStyle.displayLarge)
                        .foregroundStyle(DoggoColor.ink)
                        .multilineTextAlignment(.center)

                    Text("This is how your pack will remember you.\nNo email, no password — just a name.")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: DoggoSpacing.sm) {
                    Text("@")
                        .font(DoggoTextStyle.headline)
                        .foregroundStyle(DoggoColor.marigold)
                    TextField("scout", text: $username)
                        .font(DoggoTextStyle.headline)
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onSubmit(signUp)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.vertical, DoggoSpacing.lg)
                .padding(.horizontal, DoggoSpacing.xl)
                .background(DoggoColor.cardWhite, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .padding(.horizontal, DoggoSpacing.xl)

                Spacer()

                PillButton(title: "Let's go", action: signUp)
                    .padding(.horizontal, DoggoSpacing.xl)
                    .opacity(isValid ? 1 : 0.5)
                    .disabled(!isValid)
            }
            .padding(.bottom, DoggoSpacing.xl)
        }
        .onAppear { isFocused = true }
    }

    private func signUp() {
        guard isValid else { return }
        try? authProvider.signUp(username: username)
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(UsernameAuthProvider(modelContext: try! ModelContainer(for: UserProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
}
