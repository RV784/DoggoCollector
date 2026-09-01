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
    /// A very subtle cream-white — the bottom stop of the home-screen mesh
    /// gradient (top = `cream`, bottom = this). Nearly white, just warm enough
    /// to not read as pure #FFF.
    static let creamFade = Color(hex: 0xFFFFF0)
    static let ink = Color(hex: 0x2B2013)
    static let inkOffWhite = Color(hex: 0xE5E0D1)
    static let inkMuted = Color(hex: 0x8A7A63)

    static let cardWhite = Color(hex: 0xFFFFFF)
    static let chipCream = Color(hex: 0xF5E8D3)

    static let sky = Color(hex: 0xB7E1EA)
    static let sage = Color(hex: 0xCDE8BE)
    /// Guardian paywall v2's fourth unlock-row tile (Handover) — decision #25.
    static let lavender = Color(hex: 0xD6CCEF)

    // Guardian paywall v2 (decision #25) — extracted verbatim from the
    // "Guardian Paywall.dc.html" prototype. Its type/greys are a shade
    // finer than the app's general inkMuted scale (three distinct muted
    // greys at 13.5/12/10.5pt), so they get their own tokens rather than
    // being approximated onto existing ones.
    static let paywallRowBorder = Color(hex: 0xE7D9BE)
    static let paywallRowText   = Color(hex: 0x6E6150)
    static let paywallFaint     = Color(hex: 0xA6957B)
    static let paywallFainter   = Color(hex: 0xB7A88F)
    static let paywallListBg    = Color(hex: 0xF8F1E2)
    static let iconBell     = Color(hex: 0x3E7A34)
    static let iconPrinter  = Color(hex: 0x2A6B78)
    static let iconHandover = Color(hex: 0x6B5A96)

    static let heartPink = Color(hex: 0xF2777B)

    /// The "make a call" green — used on the gallery's Call Clinic control so
    /// a phone affordance reads as one at a glance. A touch deeper than iOS's
    /// system call green so it doesn't clash with the warm palette.
    static let callGreen = Color(hex: 0x2FA84F)

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

    // Medication tracking — from the Phase 2 design prototype. Everything
    // else in that design maps onto existing tokens above (see the plan's
    // color-mapping rule) — these are the genuinely new ones.
    static let sheetCream = Color(hex: 0xFFF6E9)
    static let dashedBorder = Color(hex: 0xEAD9BF)
    static let recordPhotoBg = Color(hex: 0xDCEBF7)
    static let recordPhotoFg = Color(hex: 0x3E93A6)
    static let recordFileBg = Color(hex: 0xF5E3A8)
    static let recordFileFg = Color(hex: 0xC0872B)
    static let inputBorder = Color(hex: 0xFFE0BC)

    // Shelter Pass redesign (Shelter Pass.dc.html) — the "warm sunlit light
    // field" behind an opaque paper pass, plus the flat print tokens. Hexes
    // lifted verbatim from the prototype.
    // Light field (Life A, on screen)
    static let passGround1 = Color(hex: 0xFFF9EC)   // warm ground ramp
    static let passGround2 = Color(hex: 0xFFEDD2)
    static let passGround3 = Color(hex: 0xFFE0BB)
    static let passGround4 = Color(hex: 0xF8D2A8)
    static let passPoolMarigold = Color(hex: 0xFFD89E)   // mesh bloom pools
    static let passPoolPeach    = Color(hex: 0xFFCBAB)
    static let passPoolSage     = Color(hex: 0xDFEBD5)
    static let passFloor        = Color(hex: 0xDB9E54)   // warm floor vignette
    static let passGrainInk     = Color(hex: 0x9A7B45)   // paper grain / guilloché
    // The paper pass + its marigold header
    static let passPaper1  = Color(hex: 0xFFFDF8)
    static let passPaper2  = Color(hex: 0xFDF3E2)
    static let passHeader1 = Color(hex: 0xFFC96B)
    static let passHeader2 = Color(hex: 0xF5A623)
    static let passHeader3 = Color(hex: 0xEF9C14)
    static let passFooter1 = Color(hex: 0xFDF6EA)
    static let passFooter2 = Color(hex: 0xFBEFDC)
    static let passHairline = Color(hex: 0xDDD5C7)
    static let passMedBg   = Color(hex: 0xFBF6EC)
    static let passHandoverBg = Color(hex: 0xF1EBE0)
    static let passHandoverBorder = Color(hex: 0xE2D6C2)
    // The paw seal (screen: warm cream + amber paw)
    static let sealCream1 = Color(hex: 0xFFFDF6)
    static let sealCream2 = Color(hex: 0xFDF0DA)
    static let sealCream3 = Color(hex: 0xF6E2C4)
    static let sealRing   = Color(hex: 0xF0C98A)
    static let sealPaw    = Color(hex: 0xE09A22)
    static let issuedInk  = Color(hex: 0x9A7B45)
    // Reduce Transparency fallback for the field
    static let passReduceTransp1 = Color(hex: 0xFBE9CE)
    static let passReduceTransp2 = Color(hex: 0xEFD3A8)
    // Life B (print) — flat, ink on white, grayscale-safe
    static let printInk    = Color(hex: 0x2B2013)
    static let printGrey   = Color(hex: 0x6E6150)
    static let printHair   = Color(hex: 0xDDD5C7)
    static let printGuilloche = Color(hex: 0x9A7B45)
    static let printEstFg  = Color(hex: 0x7C5417)
    static let printObsFg  = Color(hex: 0x2F6B3E)

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
