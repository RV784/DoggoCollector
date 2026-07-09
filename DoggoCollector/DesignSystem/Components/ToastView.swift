//
//  ToastView.swift
//  DoggoCollector
//
//  Reusable bottom toast for confirmations that don't warrant a full alert
//  (Guardian pledge/log/lifecycle confirmations). Auto-clears the bound
//  message after ~1.8s so call sites just set the binding and forget it.
//

import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.vertical, DoggoSpacing.md)
                    .background(DoggoColor.ink, in: Capsule())
                    .padding(.bottom, DoggoSpacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(1.8))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
