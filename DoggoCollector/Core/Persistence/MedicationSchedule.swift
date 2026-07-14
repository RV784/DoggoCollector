//
//  MedicationSchedule.swift
//  DoggoCollector
//
//  One tracked medication course for a ward. `dosage` is always free text,
//  user-typed — this app never suggests a dose (see drugreference/README.md
//  for the "record-keeping tool, never a treatment-suggestion tool" line
//  this whole feature is built around).
//

import Foundation
import SwiftData

@Model
final class MedicationSchedule {
    var id: UUID = UUID()
    var drugName: String = ""
    var dosage: String = ""
    var frequencyHours: Int = 12
    var startDate: Date = Date.now
    /// nil = ongoing — the default, and the honest common case.
    var endDate: Date? = nil
    var notes: String? = nil
    var dog: CaughtDog? = nil

    init(
        drugName: String,
        dosage: String,
        frequencyHours: Int = 12,
        startDate: Date = .now,
        endDate: Date? = nil,
        notes: String? = nil,
        dog: CaughtDog? = nil
    ) {
        self.id = UUID()
        self.drugName = drugName
        self.dosage = dosage
        self.frequencyHours = frequencyHours
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.dog = dog
    }

    /// Ended courses are never deleted — they just stop being "active"
    /// (same Past-Wards instinct as `WardStatus`).
    var isActive: Bool {
        endDate == nil || endDate! > .now
    }

    /// Most recent `.medicated` entry logged from this schedule's give-dose
    /// button — `CareEntry.scheduleId` is what links the two.
    func lastDose(in entries: [CareEntry]) -> CareEntry? {
        entries.filter { $0.scheduleId == id }.max { $0.timestamp < $1.timestamp }
    }

    /// If a dose has ever been given, next due = that dose + frequency —
    /// giving late honestly re-anchors the chain, it's not a bug. If never
    /// given, next due = `startDate` (which reads as "due today" for a
    /// schedule created in the moment).
    func nextDueDate(after lastDoseDate: Date?) -> Date {
        guard let lastDoseDate else { return startDate }
        return lastDoseDate.addingTimeInterval(TimeInterval(frequencyHours) * 3600)
    }

    func nextDueDate(in entries: [CareEntry]) -> Date {
        nextDueDate(after: lastDose(in: entries)?.timestamp)
    }

    /// True once the most recent logged dose still covers the current
    /// cycle (i.e. its own next-due projection is still in the future) —
    /// flips back to false, and the give-dose button re-enables, once that
    /// window passes into due-now/overdue territory. Single source of
    /// truth for both MedicationsSection and TodaysCareView, which used to
    /// compute this independently and could disagree.
    func isCurrentlyGiven(in entries: [CareEntry]) -> Bool {
        guard let lastDose = lastDose(in: entries) else { return false }
        return nextDueDate(after: lastDose.timestamp) > .now
    }

    /// The one string used to both schedule and cancel this schedule's
    /// reminder — see `MedicationReminder`.
    var notificationIdentifier: String { "med-\(id.uuidString)" }
}
