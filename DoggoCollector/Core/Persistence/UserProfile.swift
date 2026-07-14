//
//  UserProfile.swift
//  DoggoCollector
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    // Literal defaults — see CaughtDog.swift's matching comment
    // (decision #18, CloudKit compatibility).
    var id: UUID = UUID()
    var username: String = ""
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), username: String, createdAt: Date = .now) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
    }
}
