//
//  MedicationReminder.swift
//  DoggoCollector
//
//  The only place UNUserNotificationCenter is touched. One repeating
//  UNTimeIntervalNotificationTrigger per schedule keeps the app trivially
//  inside iOS's 64-pending-request cap even at real multi-dog scale (6 dogs
//  × 3 meds = 18 requests) — see the medication-tracking plan §4.
//

import Foundation
import UserNotifications

enum MedicationReminder {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Cancels any existing request for this schedule first, then registers
    /// one repeating trigger. Content names only what the user themselves
    /// typed (drug/dosage) — never a suggestion.
    static func schedule(for schedule: MedicationSchedule, dogName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [schedule.notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Time for \(dogName)'s \(schedule.drugName)"
        content.body = "\(schedule.dosage) — every \(schedule.frequencyHours) hours. Scout's on it with you."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(schedule.frequencyHours) * 3600,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: schedule.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    static func cancel(_ schedule: MedicationSchedule) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [schedule.notificationIdentifier])
    }

    static func cancelAll(for dog: CaughtDog) {
        let identifiers = (dog.medicationSchedules ?? []).map(\.notificationIdentifier)
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// A time-interval trigger's first fire is `interval` from *registration*
    /// — re-registering at dose time re-anchors the chain to the real last
    /// dose, so a late dose honestly pushes the next reminder instead of
    /// nagging on the stale cadence. Called on every give-dose tap.
    static func reanchor(_ schedule: MedicationSchedule, dogName: String) {
        self.schedule(for: schedule, dogName: dogName)
    }

    /// Reconciliation — run from a `.task` on `CollectionView` (fires on
    /// every app launch/return to home). Cancels reminders that no longer
    /// warrant one (schedule deleted/ended, or its ward archived — though
    /// `CardDetailView.archiveWard` already calls `cancelAll` directly for
    /// immediacy) and re-registers any active schedule missing a pending
    /// request (permission granted after the fact, restore from backup).
    static func sweep(dogs: [CaughtDog]) async {
        let center = UNUserNotificationCenter.current()
        let pendingMedIdentifiers = Set(
            await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix("med-") }
        )

        var validIdentifiers: Set<String> = []
        var toRegister: [(schedule: MedicationSchedule, dogName: String)] = []

        for dog in dogs where dog.isActiveWard {
            for schedule in dog.activeMedicationSchedules {
                validIdentifiers.insert(schedule.notificationIdentifier)
                if !pendingMedIdentifiers.contains(schedule.notificationIdentifier) {
                    toRegister.append((schedule, dog.name))
                }
            }
        }

        let staleIdentifiers = pendingMedIdentifiers.subtracting(validIdentifiers)
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIdentifiers))
        }

        for entry in toRegister {
            self.schedule(for: entry.schedule, dogName: entry.dogName)
        }
    }
}
