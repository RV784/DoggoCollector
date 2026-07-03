//
//  CatchNameGenerator.swift
//  DoggoCollector
//
//  Vision's animal recognizer (see DogDetector) only confirms "a dog is in
//  frame" — no custom-trained breed classifier for v1. Rather than turning
//  the peak-delight catch moment into a data-entry form, a catch gets a cute
//  generated name and a couple of generic trait chips, editable afterward in
//  Card detail. Doggo-specific content, so it lives in Mechanic/ rather than
//  Core/ or Features/.
//

import Foundation

enum CatchNameGenerator {
    private static let names = [
        "Mochi", "Biscuit", "Waffles", "Nugget", "Pepper", "Peanut",
        "Bramble", "Clover", "Noodle", "Pickle", "Sunny", "Maple",
        "Ziggy", "Otis", "Daisy", "Rocket", "Pumpkin", "Marbles",
    ]

    private static let breedLabels = [
        "Good boy", "Good girl", "Neighborhood pup", "Local legend", "New friend",
    ]

    private static let traitPool = [
        "Goofball", "Fluffy", "Zoomies", "Cuddly", "Curious", "Speedy", "Sun-seeker", "Snack-motivated",
    ]

    static func generate() -> (name: String, breedLabel: String, traits: [String]) {
        let name = names.randomElement() ?? "Buddy"
        let breedLabel = breedLabels.randomElement() ?? "Good boy"
        let traits = Array(traitPool.shuffled().prefix(2))
        return (name, breedLabel, traits)
    }
}
