//
//  GlassChrome.swift
//  DoggoCollector
//
//  Liquid Glass treatment for the app's floating chrome — circular icon
//  buttons over content (top bars, camera controls, map overlay). Content
//  elements (Scout, DoggoCardView, celebration screen, etc.) never use this;
//  see CLAUDE.md's Liquid Glass decision for the chrome-only scope.
//

import SwiftUI

struct GlassCircleChrome: ViewModifier {
    var size: CGFloat = 44
    var interactive: Bool = true
    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .contentShape(Circle())
            .glassEffect(.clear.interactive(interactive), in: .circle)
    }
}

extension View {
    func glassCircleChrome(size: CGFloat = 44, interactive: Bool = true) -> some View {
        modifier(GlassCircleChrome(size: size, interactive: interactive))
    }
}
