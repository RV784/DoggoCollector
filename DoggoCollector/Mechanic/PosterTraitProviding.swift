//
//  PosterTraitProviding.swift
//  DoggoCollector
//
//  The Poster Maker's "trait model" seam. The spec assumes a model that reads
//  physical description (colour, coat, size, ears, tail, collar + colour,
//  age, each with a confidence) off the dog's photo set. That model doesn't
//  exist yet — so v1 ships DUMMY, DETERMINISTIC traits (seeded off the dog's
//  id, same trick as MockDogInsightProvider), fully editable on the poster.
//  Views depend only on the protocol, so a real vision/AI model drops in as a
//  new conformance without touching any poster UI.
//
//  Confidence drives whether a trait arrives pre-selected: "low confidence
//  never reaches the poster — it arrives pre-selected and empty-looking
//  rather than confidently wrong" (spec §11). Here, low-confidence chips come
//  back `enabled == false`.
//

import Foundation

nonisolated struct PosterChip: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var text: String
    /// On = renders on the poster (max 3 shown). Off = the model found it but
    /// it's dropped/low-confidence; still editable back on.
    var enabled: Bool
    var confidence: Double
}

struct PosterTraitSet: Equatable {
    /// Ordered candidates. The first three `enabled` render as the poster's
    /// trait chips; the rest are droppable extras in the chip editor.
    var chips: [PosterChip]
    /// The Missing "LOOK FOR" physical line, e.g. "Tan coat, ears up, curly tail".
    var descriptorLine: String
    /// Collar chip label ("no collar" / "Brown collar") + whether one was seen.
    var collarLabel: String
    var hasCollar: Bool
    /// Rough age bracket ("Puppy" / "Young" / "Adult" / "Senior").
    var ageBracket: String
    /// Approx age in months, for the Adopt corner badge ("4" / "MONTHS").
    var ageMonths: Int
}

protocol PosterTraitProviding {
    func traits(for dog: CaughtDog, purpose: PosterPurpose) async -> PosterTraitSet
}

struct MockPosterTraitProvider: PosterTraitProviding {
    private static let colours = ["Tan", "Black", "White", "Brown", "Golden", "Brindle", "Cream", "Grey", "Black & tan"]
    private static let ears = ["ears up", "ears down", "one ear up", "floppy ears"]
    private static let tails = ["curly tail", "straight tail", "bushy tail", "short tail", "feathered tail"]
    private static let sizes = ["Small size", "Medium size", "Large size"]
    private static let collarColours = ["Brown", "Red", "Blue", "Black", "Green"]
    private static let behaviours = ["Potty trained", "Good with kids", "Friendly", "Calm", "Playful", "House trained"]

    func traits(for dog: CaughtDog, purpose: PosterPurpose) async -> PosterTraitSet {
        var rng = SeededGenerator(seed: dog.id.hashValue &+ purpose.hashValue)

        let colour = Self.colours.randomElement(using: &rng) ?? "Tan"
        let ear = Self.ears.randomElement(using: &rng) ?? "ears up"
        let tail = Self.tails.randomElement(using: &rng) ?? "curly tail"
        let size = Self.sizes.randomElement(using: &rng) ?? "Medium size"
        let hasCollar = Double.random(in: 0...1, using: &rng) < 0.35
        let collarColour = Self.collarColours.randomElement(using: &rng) ?? "Brown"
        let collarLabel = hasCollar ? "\(collarColour) collar" : "no collar"

        // Age — puppies skew common for Adopt posts.
        let months: Int
        let bracket: String
        let roll = Double.random(in: 0...1, using: &rng)
        if purpose == .adopt ? (roll < 0.6) : (roll < 0.25) {
            months = Int.random(in: 2...8, using: &rng); bracket = "Puppy"
        } else if roll < 0.6 {
            months = Int.random(in: 10...22, using: &rng); bracket = "Young"
        } else if roll < 0.9 {
            months = Int.random(in: 26...72, using: &rng); bracket = "Adult"
        } else {
            months = Int.random(in: 84...132, using: &rng); bracket = "Senior"
        }

        let descriptor = "\(colour) coat, \(ear), \(tail)"

        // Candidate chips: app-known facts first (high confidence), then the
        // physical/behavioural reads. First three enabled render on the poster.
        let breed = dog.classifiedDisplayBreed ?? (dog.breedLabel.isEmpty ? "Indie" : dog.breedLabel)
        let sex = dog.sex
        let breedSex = sex.map { "\(shortBreed(breed)) \u{00B7} \($0)" } ?? shortBreed(breed)
        let behaviour = Self.behaviours.randomElement(using: &rng) ?? "Friendly"

        var candidates: [(String, Double)] = [
            (breedSex, 0.95),
            (sterilizationChip(dog), dog.sterilization == .unknown ? 0.3 : 0.9),
            (size, 0.8),
            ("\(colour) coat", 0.75),
            (hasCollar ? collarLabel : "Vaccinated", hasCollar ? 0.7 : 0.5),
            (behaviour, 0.6),
        ]
        // Drop empty sterilization chip text.
        candidates.removeAll { $0.0.isEmpty }

        var chips = candidates.enumerated().map { i, c in
            PosterChip(text: c.0, enabled: i < 3 && c.1 >= 0.65, confidence: c.1)
        }
        // Guarantee at least three enabled so the poster is never bare.
        var enabledCount = chips.filter(\.enabled).count
        var i = 0
        while enabledCount < 3 && i < chips.count {
            if !chips[i].enabled { chips[i].enabled = true; enabledCount += 1 }
            i += 1
        }

        return PosterTraitSet(
            chips: chips,
            descriptorLine: descriptor,
            collarLabel: collarLabel,
            hasCollar: hasCollar,
            ageBracket: bracket,
            ageMonths: months
        )
    }

    private func shortBreed(_ breed: String) -> String {
        // "Indie mix" → "Indie", "Labrador mix" → "Labrador" for chip brevity.
        breed.replacingOccurrences(of: " mix", with: "")
    }

    private func sterilizationChip(_ dog: CaughtDog) -> String {
        switch dog.sterilization {
        case .done: return dog.sex == "Female" ? "Spayed" : "Neutered"
        case .notYet: return "Not neutered"
        case .unknown: return "Vaccinated"
        }
    }
}
