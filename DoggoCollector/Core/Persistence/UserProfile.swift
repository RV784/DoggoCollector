//
//  UserProfile.swift
//  DoggoCollector
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var username: String
    var createdAt: Date

    init(id: UUID = UUID(), username: String, createdAt: Date = .now) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
    }
}
