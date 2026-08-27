//
//  PosterPalette.swift
//  DoggoCollector
//
//  The Poster Maker's colour system, lifted verbatim from the v2 design's
//  `PALETTES` / `VARIANT_ROWS` (see ~/Documents/poster_maker_design_extract.md).
//  Kept in its own type rather than folded into DoggoColor: it's a closed,
//  self-contained system (three high-key analogous grounds, one saturated
//  accent used on ~12% of the frame) that the rest of the app never touches.
//
//  Each purpose sits on a warm/cool/sunny ground with five curated accent
//  variants — "curated, not a colour picker: a guardian cannot produce an
//  unreadable poster" (spec §11).
//

import SwiftUI

/// One accent choice: the saturated accent + its deep tone + the matched
/// high-key ground (2 or 3 gradient stops, top→bottom at 168°) + the chip tint.
struct PosterAccent: Equatable {
    let accent: Color
    let deep: Color
    let grounds: [Color]
    let tint: Color

    var groundGradient: LinearGradient {
        LinearGradient(colors: grounds, startPoint: .top, endPoint: .bottom)
    }
}

enum PosterPurpose: String, CaseIterable, Codable {
    case missing, found, adopt

    var title: String {
        switch self {
        case .missing: return "Missing"
        case .found: return "Found"
        case .adopt: return "Adopt"
        }
    }

    // MARK: - Accent variants (5 per purpose) — [accent, deep, grounds…, tint]

    var accents: [PosterAccent] {
        switch self {
        case .missing:
            return [
                // default carries the poster file's exact 3-stop mid (#FFE9D8)
                .init(accent: c(0xE4572E), deep: c(0xC13F1C), grounds: [c(0xFFF6EC), c(0xFFE9D8), c(0xFFD9C2)], tint: c(0xFFE4D6)),
                .init(accent: c(0xD6452B), deep: c(0xB03A22), grounds: [c(0xFFF4EA), c(0xFFD3C4)], tint: c(0xFFE0D4)),
                .init(accent: c(0xC9445A), deep: c(0xA83848), grounds: [c(0xFFF2F1), c(0xFFD5D6)], tint: c(0xFFE2E2)),
                .init(accent: c(0xE07A3C), deep: c(0xC0632B), grounds: [c(0xFFF8EC), c(0xFFE2C4)], tint: c(0xFFEBD6)),
                .init(accent: c(0xB24A38), deep: c(0x93382A), grounds: [c(0xFCF3EC), c(0xF5D6C6)], tint: c(0xF7E2D8)),
            ]
        case .found:
            return [
                .init(accent: c(0x2E8B7A), deep: c(0x1F6D5F), grounds: [c(0xF4FBF7), c(0xDFF3EA), c(0xC8EADC)], tint: c(0xD7F0E5)),
                .init(accent: c(0x2E7E93), deep: c(0x1F6376), grounds: [c(0xF2FAFC), c(0xC6E6EE)], tint: c(0xD6EEF4)),
                .init(accent: c(0x3B6FB0), deep: c(0x2C568C), grounds: [c(0xF4F8FD), c(0xCFDFF3)], tint: c(0xDDE9F8)),
                .init(accent: c(0x4A9A55), deep: c(0x37773F), grounds: [c(0xF5FBF2), c(0xD2EBCB)], tint: c(0xE4F4DE)),
                .init(accent: c(0x1F6D5F), deep: c(0x16564A), grounds: [c(0xF1F9F5), c(0xC0E4D7)], tint: c(0xD0EDE2)),
            ]
        case .adopt:
            return [
                .init(accent: c(0xF0932B), deep: c(0xA9611A), grounds: [c(0xFFFBEC), c(0xFFEFCF), c(0xFFE0AE)], tint: c(0xFFEBC4)),
                .init(accent: c(0x5AA95F), deep: c(0x417F46), grounds: [c(0xF6FBF3), c(0xD6EDCF)], tint: c(0xE4F4DE)),
                .init(accent: c(0xE45A86), deep: c(0xC0446B), grounds: [c(0xFFF5F8), c(0xFFD6E2)], tint: c(0xFFE3EC)),
                .init(accent: c(0x8B6BC9), deep: c(0x6B4FA5), grounds: [c(0xF9F6FD), c(0xE0D5F5)], tint: c(0xEBE3F9)),
                .init(accent: c(0xD9773D), deep: c(0xB25C29), grounds: [c(0xFFF7EF), c(0xFBDCC0)], tint: c(0xFDE8D6)),
            ]
        }
    }

    func accent(_ index: Int) -> PosterAccent {
        let all = accents
        return all[min(max(index, 0), all.count - 1)]
    }

    // MARK: - Decorative colours (from the poster files)

    /// Second radial highlight tint (top-right of the ground).
    var glowTint: Color {
        switch self {
        case .missing: return c(0xFFDFC9)
        case .found: return c(0xCEEEE2)
        case .adopt: return c(0xFFE7BE)
        }
    }

    /// The soft corner blob circle + which corner it sits in.
    var blobColor: Color {
        switch self {
        case .missing: return c(0xFFCDAF)
        case .found: return c(0xA8D8C7)
        case .adopt: return c(0xFFD592)
        }
    }
    var blobLeading: Bool { self != .found }   // Missing/Adopt left, Found right

    /// The playful paw marks scattered top-left/right.
    var pawMarkColor: Color {
        switch self {
        case .missing: return c(0xF3B79A)
        case .found: return c(0xA8D8C7)
        case .adopt: return c(0xF3C889)
        }
    }

    /// The top-left corner badge (days missing / date found / age).
    var badgeBg: Color {
        switch self {
        case .missing: return c(0xFFE0CD)
        case .found: return c(0xD7F0E5)
        case .adopt: return c(0xFFEBC4)
        }
    }
    var badgeLabel: Color {
        switch self {
        case .missing: return c(0xC98763)
        case .found: return c(0x5F9284)
        case .adopt: return c(0xB98F4A)
        }
    }

    /// Eyebrow label colour used inside the white block and the sub-line.
    var eyebrow: Color {
        switch self {
        case .missing: return c(0xB08163)
        case .found: return c(0x7D958C)
        case .adopt: return c(0xA08A6A)
        }
    }

    /// The signature paw (muted, bottom-right).
    var sigPaw: Color {
        switch self {
        case .missing: return c(0xC99A7E)
        case .found: return c(0x8FB5A9)
        case .adopt: return c(0xCBA26A)
        }
    }

    /// Bottom-left tagline text colour.
    var taglineColor: Color {
        switch self {
        case .missing: return c(0xC9A78F)
        case .found: return c(0x9BBBB0)
        case .adopt: return c(0xC2A87E)
        }
    }

    /// Bottom-left tagline copy.
    var tagline: String {
        switch self {
        case .missing, .found: return "PLEASE SHARE"
        case .adopt: return "ADOPT. DON\u{2019}T SHOP."
        }
    }

    // Shared ink tones (same across purposes).
    static let ink = c(0x2E1F16)
    static let cream = c(0xFFF8EC)

    private func c(_ hex: UInt32) -> Color { Color(hex: hex) }
    private static func c(_ hex: UInt32) -> Color { Color(hex: hex) }
}
