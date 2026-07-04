//
//  SeededGenerator.swift
//  DoggoCollector
//
//  A deterministic RandomNumberGenerator seeded from an Int. Lets mock
//  content (insight guesses, the care directory) stay stable across repeat
//  visits for the same dog/session instead of reshuffling on every render —
//  same spirit as the `placeholderSeed = dog.id.hashValue` trick already
//  used for card placeholder tints.
//

import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
