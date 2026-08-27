//
//  PosterModel.swift
//  DoggoCollector
//
//  The Poster Maker's value types: the editable copy (`PosterContent`, the
//  JSON blob a Poster persists) with a per-purpose default factory, and the
//  flattened `PosterRenderModel` that `PosterView` renders (so the poster is a
//  pure function of its inputs — the same view drives the editor, the ceremony
//  end-state, and the ImageRenderer export).
//
//  Copy defaults are the design's own strings where the value is generic, and
//  the dog's real data (name, territory, breed, sex) where the app already has
//  it. The guardian's phone isn't in the app (Phase-1 auth is local username
//  only), so it defaults empty and is a first-class edit target — the contact
//  bar is "the point" (spec §5).
//

import Foundation
import UIKit

/// Every editable string on the poster, purpose-agnostic. Fields not used by a
/// given purpose stay empty and simply don't render.
/// `nonisolated` so its synthesized Codable conformance is usable from the
/// `Poster` @Model's (nonisolated) JSON accessors under the project's
/// default-MainActor isolation.
nonisolated struct PosterContent: Codable, Equatable {
    var name: String = ""
    var akaLine: String = ""            // Adopt Caveat aka-line
    var subLine: String = ""            // Missing "HELP US GET HIM HOME"
    var headlineQuestion: String = ""   // Found "Is this your dog?"
    var kickerText: String = ""         // "Missing dog" / "Found safe" / "Adopt me"
    var kickerPrefix: String = ""       // Adopt handwritten "meet"

    var badgeValue: String = ""         // "2" / "10" / "4"
    var badgeUnit: String = ""          // "DAYS" / "AUG" / "MONTHS"

    var blockLeftLabel: String = ""     // "LAST SEEN" / "FOUND ON" / "SHE NEEDS"
    var blockLeftBig: String = ""       // big accent value (date, or Adopt's needs line)
    var blockLeftSmall: String = ""     // "around 9 in the morning"
    var blockRightLabel: String = ""    // "RIGHT AROUND" / "LOOKING IN"
    var blockRightValue: String = ""    // place / city
    var blockRightSmall: String = ""    // Adopt "or nearby, we drive"
    /// Adopt puts the big fixed-width value (city) on the right; Missing/Found
    /// put it (the date) on the left.
    var blockBigOnRight: Bool = false

    var blockBottomLabel: String = ""   // "LOOK FOR" / (none) / "SHE IS ALREADY"
    var blockBottomText: String = ""    // descriptor / reassurance / behavioural
    var blockBottomChip: String = ""    // "no collar" / "all clear"
    var blockBottomStyle: BottomStyle = .textChip

    var contactLabel: String = ""       // "SEEN HIM?\nCALL ANYTIME"
    var phone: String = ""
    var contactCaption: String = ""     // "Rajat, and he means anytime"

    var freeLine: String = ""           // Caveat, ≤90 — caption on 9:16, poster on 4:5

    enum BottomStyle: String, Codable { case textChip, checkPill, none }

    /// Builds sensible per-purpose defaults from the dog + dummy traits.
    static func make(purpose: PosterPurpose, dog: CaughtDog, traits: PosterTraitSet, username: String) -> PosterContent {
        var c = PosterContent()
        let place = cleanPlace(dog.locationLabel)
        let dayMonth = df("d MMM").string(from: .now)
        let monthAbbr = df("MMM").string(from: .now).uppercased()
        let dayNum = df("d").string(from: .now)

        switch purpose {
        case .missing:
            c.name = dog.name
            c.kickerText = "Missing dog"
            c.subLine = "HELP US GET HIM HOME"
            c.badgeValue = "1"; c.badgeUnit = "DAY"
            c.blockLeftLabel = "LAST SEEN"; c.blockLeftBig = dayMonth; c.blockLeftSmall = "around 9 in the morning"
            c.blockRightLabel = "RIGHT AROUND"; c.blockRightValue = place
            c.blockBottomLabel = "LOOK FOR"; c.blockBottomText = traits.descriptorLine
            c.blockBottomChip = traits.collarLabel; c.blockBottomStyle = .textChip
            c.contactLabel = "SEEN HIM?\nCALL ANYTIME"
            c.contactCaption = username.isEmpty ? "reach out anytime" : "\(username), and they mean anytime"

        case .found:
            c.kickerText = "Found safe"
            c.headlineQuestion = "Is this your dog?"
            c.badgeValue = dayNum; c.badgeUnit = monthAbbr
            c.blockLeftLabel = "FOUND ON"; c.blockLeftBig = dayMonth; c.blockLeftSmall = "in the evening"
            c.blockRightLabel = "RIGHT AROUND"; c.blockRightValue = place
            c.blockBottomText = "They\u{2019}re safe with me right now"; c.blockBottomStyle = .checkPill
            c.contactLabel = "IS THIS\nYOURS?"
            c.contactCaption = username.isEmpty ? "bring a photo to confirm" : "\(username), bring a photo to confirm"

        case .adopt:
            c.name = dog.name
            c.kickerPrefix = "meet"; c.kickerText = "Adopt me"
            c.akaLine = akaFor(traits)
            let (bv, bu) = ageBadge(traits)
            c.badgeValue = bv; c.badgeUnit = bu
            c.blockLeftLabel = "NEEDS"; c.blockLeftBig = "A home, and a floor to nap on"
            c.blockRightLabel = "LOOKING IN"; c.blockRightValue = place.isEmpty ? "your city" : firstWord(place)
            c.blockRightSmall = "or nearby, we drive"; c.blockBigOnRight = true
            c.blockBottomLabel = "ALREADY"; c.blockBottomText = "Good with kids, dogs, floors"
            c.blockBottomChip = "all clear"; c.blockBottomStyle = .textChip
            c.contactLabel = "TO ADOPT\n\(dog.name.uppercased())"
            c.contactCaption = username.isEmpty ? "a home visit comes first" : "\(username), a home visit comes first"
        }
        return c
    }

    // MARK: - Helpers

    private static func df(_ format: String) -> DateFormatter {
        let f = DateFormatter(); f.dateFormat = format; return f
    }

    /// "Somewhere nearby"/empty placeholders → empty (editable), otherwise the label.
    private static func cleanPlace(_ label: String) -> String {
        let l = label.trimmingCharacters(in: .whitespaces)
        if l.isEmpty || l.lowercased() == "somewhere nearby" { return "" }
        return l
    }

    private static func firstWord(_ s: String) -> String {
        s.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? s
    }

    private static func ageBadge(_ traits: PosterTraitSet) -> (String, String) {
        let m = traits.ageMonths
        if m < 24 { return ("\(m)", "MONTHS") }
        let years = m / 12
        return ("\(years)", years == 1 ? "YEAR" : "YEARS")
    }

    private static func akaFor(_ traits: PosterTraitSet) -> String {
        let m = traits.ageMonths
        if m < 24 { return "\(m) months old, entirely made of tail" }
        return "\(traits.ageBracket.lowercased()), and impossibly good" }
}

/// Everything `PosterView` needs to draw one poster — a pure snapshot.
struct PosterRenderModel {
    let purpose: PosterPurpose
    let accent: PosterAccent
    let layout: PosterLayout
    let content: PosterContent
    /// The three chip texts that render (already filtered to enabled, ≤3).
    let chips: [String]
    /// The hero image: a cutout for the hero layouts, the raw photo for
    /// photo-led. nil → the soft placeholder bloom (still a valid poster).
    let hero: UIImage?
    /// Up to two polaroid photos (raw).
    let polaroids: [UIImage?]
    /// Number off replaces the contact bar with an in-app chat QR.
    var numberVisible = true
    /// 4:5 export reclaims the safe strips, grows the hero, and brings the
    /// Caveat free line onto the poster instead of the caption.
    var render45 = false
}
