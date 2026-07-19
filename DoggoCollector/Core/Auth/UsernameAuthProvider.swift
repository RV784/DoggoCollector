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
        Self.dedupeProfiles(in: modelContext)
        self.currentUsername = try? Self.fetchProfile(in: modelContext)?.username
    }

    func signUp(username: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Adopt an existing profile instead of inserting a second one —
        // with CloudKit sync (decision #18), a profile created on another
        // device can arrive mid-onboarding on this one, and an
        // unconditional insert here would leave two rows racing forever
        // (fetchProfile picks the oldest, so the two devices could even
        // disagree on the username). One-profile is the invariant;
        // dedupeProfiles covers the case where both devices already
        // inserted before ever syncing.
        if let existing = try Self.fetchProfile(in: modelContext) {
            existing.username = trimmed
        } else {
            modelContext.insert(UserProfile(username: trimmed))
        }
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

    /// Self-heal to the one-profile invariant: two devices that each
    /// onboarded locally before CloudKit sync merged their stores end up
    /// with one profile row per device. Keep the oldest (the same row
    /// `fetchProfile` already prefers, so both devices converge on the same
    /// winner deterministically) and delete the rest — the deletes sync
    /// too, healing the other device's store as well.
    private static func dedupeProfiles(in context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        guard let profiles = try? context.fetch(descriptor), profiles.count > 1 else { return }
        for extra in profiles.dropFirst() {
            context.delete(extra)
        }
        try? context.save()
    }
}
