//
//  UsernameAuthProvider.swift
//  DoggoCollector
//

import Foundation
import SwiftData

@Observable
final class UsernameAuthProvider: AuthProviding {
    private(set) var currentUsername: String?
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.currentUsername = try? Self.fetchProfile(in: modelContext)?.username
    }

    func signUp(username: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = UserProfile(username: trimmed)
        modelContext.insert(profile)
        try modelContext.save()
        currentUsername = trimmed
    }

    func updateUsername(_ username: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let profile = try Self.fetchProfile(in: modelContext) {
            profile.username = trimmed
        } else {
            modelContext.insert(UserProfile(username: trimmed))
        }
        try modelContext.save()
        currentUsername = trimmed
    }

    func signOut() {
        currentUsername = nil
    }

    private static func fetchProfile(in context: ModelContext) throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
