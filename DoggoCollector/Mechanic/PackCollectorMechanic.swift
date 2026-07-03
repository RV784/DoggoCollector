//
//  PackCollectorMechanic.swift
//  DoggoCollector
//
//  Doggo's hook is collector-first, not a walk-streak — you just catch real
//  dogs you meet. This computes the "Your Pack" home dashboard stats from
//  whatever's actually been caught, with no separate mutable streak state to
//  maintain.
//

import Foundation

struct PackCollectorMechanic: CollectorMechanic {
    let homeTitle = "Your Pack"

    func greeting(username: String, now: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        default: timeOfDay = "Good evening"
        }
        return "\(timeOfDay), \(username)".uppercased()
    }

    func stats(for catches: [CaughtDog]) -> [PackStat] {
        let caughtCount = catches.count
        let breedCount = Set(catches.map(\.breedLabel)).count
        let todayCount = catches.filter { Calendar.current.isDateInToday($0.caughtAt) }.count
        return [
            PackStat(label: "\(caughtCount) caught", isPrimary: true),
            PackStat(label: "\(breedCount) breeds", isPrimary: false),
            PackStat(label: "\(todayCount) today", isPrimary: false),
        ]
    }
}
