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
    
    static let marigoldContrast = Color(hex: 0x0E7490)

    static let cream = Color(hex: 0xFDEFDC)
    static let ink = Color(hex: 0x2B2013)
    static let inkOffWhite = Color(hex: 0xE5E0D1)
    static let inkMuted = Color(hex: 0x8A7A63)

    static let cardWhite = Color(hex: 0xFFFFFF)
    static let chipCream = Color(hex: 0xF5E8D3)

    static let sky = Color(hex: 0xB7E1EA)
    static let sage = Color(hex: 0xCDE8BE)

    static let heartPink = Color(hex: 0xF2777B)

    /// Eyebrow-label color for the Share card's secondary metadata row only.
    static let metadataLabel = Color(hex: 0xB29A78)

    // Guardian Mode — status (soft, no alarm red)
    static let statusDoneBg      = Color(hex: 0xEAF6E7)
    static let statusDoneBorder  = Color(hex: 0xCDE8BE)
    static let statusDoneAccent  = Color(hex: 0x3E8E52)
    static let statusAttnBg      = Color(hex: 0xFFF0D8)
    static let statusAttnBorder  = Color(hex: 0xF0DEBF)
    static let statusAttnAccent  = Color(hex: 0xD69A3C)
    static let statusUnknownBg     = Color(hex: 0xF1EBE0)
    static let statusUnknownBorder = Color(hex: 0xE2D6C2)
    // Guardian Mode — care-log tile tints (from the design prototype source)
    static let logFedBg      = Color(hex: 0xFFF0D8);  static let logFedFg      = Color(hex: 0xE0A21A)
    static let logMedBg      = Color(hex: 0xEDE6F2);  static let logMedFg      = Color(hex: 0x7A6A93)
    static let logInjuryBg   = Color(hex: 0xFBE0DF);  static let logInjuryFg   = Color(hex: 0xD66666)
    static let logVaxBg      = Color(hex: 0xE2F1DE);  static let logVaxFg      = Color(hex: 0x4E9B47)
    // Shelter Pass provenance tags
    static let provEstBg = Color(hex: 0xF3E4CC);  static let provEstFg = Color(hex: 0x9A7B45)
    static let provObsBg = Color(hex: 0xE6F0E8);  static let provObsFg = Color(hex: 0x3E8E52)

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
