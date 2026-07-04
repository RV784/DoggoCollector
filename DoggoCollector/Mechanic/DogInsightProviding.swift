//
//  DogInsightProviding.swift
//  DoggoCollector
//
//  "Scout's Sniff" — the Card Detail insight panel's data source. No real
//  breed classifier exists (see DogDetector — Vision only confirms "a dog is
//  in frame"), so this is a mock/generated stand-in seeded by the dog's own
//  id, same trick as CatchNameGenerator. A real Apple Intelligence-backed
//  conformance is a planned follow-up; views should depend only on the
//  protocol, never on MockDogInsightProvider directly.
//

import Foundation

enum DogAgeBracket: String, CaseIterable {
    case puppy = "Puppy"
    case youngAdult = "Young adult"
    case adult = "Adult"
    case senior = "Senior"
}

struct DogInsight {
    let breedGuess: String
    let isConfident: Bool
    let ageBracket: DogAgeBracket
    let careTips: [String]
    let didYouKnowFact: String
}

protocol DogInsightProviding {
    func insight(for dog: CaughtDog) async -> DogInsight
}

struct MockDogInsightProvider: DogInsightProviding {
    private static let breedGuesses = [
        "Indie mix", "Indie mix", "Indie mix", // weighted — the common, first-class case
        "Labrador mix", "Golden Retriever mix", "Shepherd mix", "Terrier mix", "Spitz mix",
    ]

    private static let careTipPool = [
        "Offer water before treats — they're probably thirstier than hungry.",
        "Let them rest somewhere shady, especially in the middle of the day.",
        "Go easy on human food — some of it isn't safe for dogs.",
        "A calm, quiet approach works best with a dog you've just met.",
        "A gentle scratch under the chin beats a full-body hug for a first hello.",
        "If they seem unsure, let them come to you instead of reaching first.",
    ]

    private static let didYouKnowPool = [
        "Many cities run local sterilization and vaccination programs for community dogs — feeding one doesn't mean you're on your own.",
        "Indie (mixed-breed) dogs are often hardier and better adapted to local weather than purebreds.",
        "Feeding a street dog doesn't make you their legal owner almost anywhere — but it definitely makes you their favorite person.",
        "A wagging tail doesn't always mean happy — the whole body tells the story, not just the tail.",
        "Community dogs often look out for their block the same way a pet dog looks out for its yard.",
    ]

    func insight(for dog: CaughtDog) async -> DogInsight {
        var rng = SeededGenerator(seed: dog.id.hashValue)

        let isConfident = Double.random(in: 0...1, using: &rng) < 0.85
        let breedGuess = Self.breedGuesses.randomElement(using: &rng) ?? "Indie mix"
        let ageBracket = DogAgeBracket.allCases.randomElement(using: &rng) ?? .adult
        let tipCount = Int.random(in: 2...3, using: &rng)
        let tips = Array(Self.careTipPool.shuffled(using: &rng).prefix(tipCount))
        let fact = Self.didYouKnowPool.randomElement(using: &rng) ?? Self.didYouKnowPool[0]

        return DogInsight(
            breedGuess: breedGuess,
            isConfident: isConfident,
            ageBracket: ageBracket,
            careTips: tips,
            didYouKnowFact: fact
        )
    }
}
