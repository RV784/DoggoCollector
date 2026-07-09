//
//  CareEntry.swift
//  DoggoCollector
//
//  One row in a ward's care timeline, logged with a single tap from
//  LogInteractionSheet. Notes stay empty from that flow (see the sheet) —
//  this model supports notes for future/manual entry, not seeded fake data.
//

import Foundation
import SwiftData

@Model
final class CareEntry {
    var id: UUID = UUID()
    var typeRaw: String = CareEntryType.fed.rawValue
    var note: String = ""
    var timestamp: Date = Date.now
    var dog: CaughtDog?

    init(type: CareEntryType, note: String = "", timestamp: Date = .now, dog: CaughtDog? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.note = note
        self.timestamp = timestamp
        self.dog = dog
    }

    var type: CareEntryType {
        get { CareEntryType(rawValue: typeRaw) ?? .fed }
        set { typeRaw = newValue.rawValue }
    }
}
