//
//  PillButton.swift
//  DoggoCollector
//

import SwiftUI

/// The app's one-dominant-action-per-screen primary/secondary CTA, per the
/// design brief's "no competing buttons at equal visual weight" rule.
struct PillButton: View {
    enum Style {
        case primary
        case secondary
    }

    var title: String
    var systemImage: String? = nil
    var style: Style = .primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DoggoSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(DoggoTextStyle.bodySemibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DoggoSpacing.lg)
            .foregroundStyle(foregroundColor)
//            .background(backgroundColor, in: Capsule())
            .glassEffect(.clear.tint(DoggoColor.marigold).interactive(), in: .rect(cornerRadius: DoggoRadius.pill))
            // Without this the Button only hit-tests the label glyphs —
            // `.frame(maxWidth: .infinity)` grows the layout but not the
            // tappable region, so taps on the empty part of the pill fell
            // straight through to whatever was underneath. Make the whole
            // pill shape the hit target.
            .contentShape(.rect(cornerRadius: DoggoRadius.pill))
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: DoggoColor.ink
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: DoggoColor.marigold
        case .secondary: DoggoColor.cardWhite
        }
    }
}

/// Underlined text-link secondary action ("I already have a pack", "Share instead").
struct TextLinkButton: View {
    var title: String
    var color: Color = DoggoColor.marigold
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DoggoTextStyle.bodySemibold)
                .underline()
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

/// Gentle press-down feedback used across all primary buttons for the
/// "juicy, native, not web-ported" feel the build spec calls for.
struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PillButton(title: "Get started", action: {})
        PillButton(title: "Catch a doggo", systemImage: "camera.fill", action: {})
        PillButton(title: "Add to pack", style: .secondary, action: {})
        TextLinkButton(title: "I already have a pack", action: {})
    }
    .padding()
    .background(DoggoColor.cream)
}
