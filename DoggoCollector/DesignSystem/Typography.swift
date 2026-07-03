//
//  Typography.swift
//  DoggoCollector
//
//  Type scale for the "Sunny Fetch" system. Uses SF Rounded for both display
//  and body roles for now — the brand's actual pairing (Baloo 2 / Nunito Sans)
//  is a phase 2 addition once font embedding is revisited.
//

import SwiftUI

enum DoggoFont {
    /// Big, bold, storybook-feeling headlines — screen titles, "Gotcha!", dog names.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Body copy, buttons, chips, captions.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum DoggoTextStyle {
    static let displayLarge = DoggoFont.display(34, weight: .bold)
    static let displayMedium = DoggoFont.display(28, weight: .bold)
    static let headline = DoggoFont.display(22, weight: .bold)
    static let bodyRegular = DoggoFont.body(17, weight: .regular)
    static let bodySemibold = DoggoFont.body(17, weight: .semibold)
    static let caption = DoggoFont.body(13, weight: .medium)
    static let eyebrow = DoggoFont.body(12, weight: .bold)
}
