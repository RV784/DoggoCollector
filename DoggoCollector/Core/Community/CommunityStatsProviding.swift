//
//  CommunityStatsProviding.swift
//  DoggoCollector
//
//  Data source for Map's Neighborhood Pulse (Flow 3). Local-only for now —
//  computed purely from this device's own catches, grouped by locality, per
//  the explicit decision to build the UI ahead of the real (Firebase-backed,
//  multi-user) community data source. Views should depend only on the
//  protocol, never on LocalCommunityStatsProvider directly.
//
//  HARD RULE (per design brief): Neighborhood Pulse only ever renders
//  locality-level aggregates — never individual pins or CaughtDog values.
//  Keep that boundary at this layer too: this type only ever returns
//  grouped, counted stats, never a raw CaughtDog.
//

import Foundation

struct LocalityStat: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let latitude: Double
    let longitude: Double
}

protocol CommunityStatsProviding {
    func localityStats(for catches: [CaughtDog]) -> [LocalityStat]
}

struct LocalCommunityStatsProvider: CommunityStatsProviding {
    func localityStats(for catches: [CaughtDog]) -> [LocalityStat] {
        Dictionary(grouping: catches, by: \.locationLabel)
            .map { name, dogs in
                let latitude = dogs.map(\.latitude).reduce(0, +) / Double(dogs.count)
                let longitude = dogs.map(\.longitude).reduce(0, +) / Double(dogs.count)
                return LocalityStat(name: name, count: dogs.count, latitude: latitude, longitude: longitude)
            }
            .sorted { $0.count > $1.count }
    }
}
