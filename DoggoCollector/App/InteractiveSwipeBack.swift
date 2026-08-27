//
//  InteractiveSwipeBack.swift
//  DoggoCollector
//
//  Restores the "swipe from the left edge to go back" gesture on pushed
//  screens. Every pushed screen in this app sets
//  `.navigationBarBackButtonHidden(true)` (+ a custom toolbar back button),
//  and UIKit ties the interactive pop gesture to the presence of the *system*
//  back button — so hiding it silently kills the edge swipe. Overriding the
//  gesture recognizer's delegate restores it without bringing the system
//  button back.
//
//  Installed once on the NavigationStack's root content: the gesture and its
//  delegate live on the UINavigationController, so a single install covers
//  every push in that stack.
//

import SwiftUI
import UIKit

/// Global opt-out. Map sets this while it's on screen so the edge swipe never
/// competes with panning the map (per the "leave Map out" requirement).
enum InteractiveSwipeBack {
    static var isSuppressed = false
}

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Proxy(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !InteractiveSwipeBack.isSuppressed else { return false }
            // Only allow the swipe when there's actually a screen to pop back to.
            return (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    /// A tiny host VC whose only job is to reach the enclosing
    /// UINavigationController and take over its pop-gesture delegate.
    final class Proxy: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            // Defer so the VC is fully in the hierarchy and `navigationController`
            // resolves to the NavigationStack's controller.
            DispatchQueue.main.async { [weak self] in
                guard let self, let nav = self.navigationController else { return }
                self.coordinator.navigationController = nav
                nav.interactivePopGestureRecognizer?.delegate = self.coordinator
                nav.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
    }
}

extension View {
    /// Enable left-edge swipe-back for the enclosing NavigationStack's pushes.
    /// Apply once to the stack's root content.
    func enableInteractiveSwipeBack() -> some View {
        background(SwipeBackEnabler())
    }
}
