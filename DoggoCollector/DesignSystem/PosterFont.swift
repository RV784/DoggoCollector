//
//  PosterFont.swift
//  DoggoCollector
//
//  The Poster Maker is the one surface that uses the brand's real display
//  pairing instead of the app-wide SF Rounded placeholder (CLAUDE.md
//  decision #2). Three OFL faces are bundled as static per-weight TTFs under
//  Resources/Fonts and registered once at launch:
//
//    Baloo 2      — the voice: kicker, name, dates, place, facts, phone number
//    Nunito Sans  — structural: chips, eyebrow labels, small print
//    Caveat       — the one handwritten line (Adopt "meet"/aka, guardian line)
//
//  Font.custom is called with each face's PostScript name (verified off the
//  actual files: Baloo2-ExtraBold / Baloo2-Bold / NunitoSans-Black /
//  NunitoSans-ExtraBold / NunitoSans-Bold / Caveat-Bold) — the most reliable
//  key, since these static instances each register as their own family. If a
//  face somehow fails to register, Font.custom degrades to the system font at
//  the requested size rather than crashing, so the poster still renders.
//

import SwiftUI
import CoreText

enum PosterFont {
    /// Registered once, idempotently, from DoggoCollectorApp at launch.
    private static let registerOnce: Void = {
        // The basenames on disk (Resources/Fonts). Synchronized-group copy
        // flattens resources to the bundle root, but try a Fonts/ subdir too
        // in case the layout is preserved.
        let files = ["Baloo2-700", "Baloo2-800",
                     "NunitoSans-700", "NunitoSans-800", "NunitoSans-900",
                     "Caveat-700"]
        for name in files {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func register() { _ = registerOnce }

    // MARK: - Faces (by PostScript name)

    /// Baloo 2 — the display voice. 800 (ExtraBold) is the default weight used
    /// almost everywhere on the poster; 700 (Bold) is available for lighter use.
    static func baloo(_ size: CGFloat, weight: Baloo = .extraBold) -> Font {
        .custom(weight.psName, size: size)
    }

    /// Nunito Sans — structural type. 900 (Black) for chips/eyebrows,
    /// 800 (ExtraBold) for values, 700 (Bold) for captions.
    static func nunito(_ size: CGFloat, weight: Nunito = .black) -> Font {
        .custom(weight.psName, size: size)
    }

    /// Caveat — the single handwritten line.
    static func caveat(_ size: CGFloat) -> Font {
        .custom("Caveat-Bold", size: size)
    }

    enum Baloo {
        case bold, extraBold
        var psName: String { self == .extraBold ? "Baloo2-ExtraBold" : "Baloo2-Bold" }
    }

    enum Nunito {
        case bold, extraBold, black
        var psName: String {
            switch self {
            case .bold: return "NunitoSans-Bold"
            case .extraBold: return "NunitoSans-ExtraBold"
            case .black: return "NunitoSans-Black"
            }
        }
    }
}
