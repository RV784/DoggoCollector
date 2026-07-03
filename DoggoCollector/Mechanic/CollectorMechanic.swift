//
//  CollectorMechanic.swift
//  DoggoCollector
//
//  Owns the home-screen hook — the one thing that's supposed to differ per
//  app in the Collector family. Doggo's concrete mechanic
//  (`PackCollectorMechanic`) is collection-stats-only; a sibling app could
//  implement something entirely different (e.g. a streak) behind this same
//  seam without touching Features/, Core/, or DesignSystem/.
//

import Foundation

protocol CollectorMechanic {
    var homeTitle: String { get }
    func greeting(username: String, now: Date) -> String
    func stats(for catches: [CaughtDog]) -> [PackStat]
}

struct PackStat: Identifiable {
    let id = UUID()
    let label: String
    let isPrimary: Bool
}
