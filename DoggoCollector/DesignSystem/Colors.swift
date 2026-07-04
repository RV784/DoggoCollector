//
//  Colors.swift
//  DoggoCollector
//
//  Design tokens — "Sunny Fetch" palette, captured from the approved design.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Sunny Fetch design tokens. Two brand hues (marigold + cream) plus a
/// scene-specific sky/sage gradient used only in the camera viewfinder —
/// keeps the palette to the "2-3 max" rule from the design brief.
enum DoggoColor {
    static let marigold = Color(hex: 0xF5A623)
    static let marigoldDark = Color(hex: 0xE08E0B)

    static let cream = Color(hex: 0xFDEFDC)
    static let ink = Color(hex: 0x2B2013)
    static let inkMuted = Color(hex: 0x8A7A63)

    static let cardWhite = Color(hex: 0xFFFFFF)
    static let chipCream = Color(hex: 0xF5E8D3)

    static let sky = Color(hex: 0xB7E1EA)
    static let sage = Color(hex: 0xCDE8BE)

    static let heartPink = Color(hex: 0xF2777B)

    /// Eyebrow-label color for the Share card's secondary metadata row only.
    static let metadataLabel = Color(hex: 0xB29A78)

    static let cameraGradient = LinearGradient(
        colors: [sky, sage],
        startPoint: .top,
        endPoint: .bottom
    )

    static let launchGradient = LinearGradient(
        colors: [marigold, marigoldDark],
        startPoint: .top,
        endPoint: .bottom
    )
}
