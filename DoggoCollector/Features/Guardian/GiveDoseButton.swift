//
//  GiveDoseButton.swift
//  DoggoCollector
//
//  Shared between MedicationsSection (Dossier) and TodaysCareView — same
//  settle behavior everywhere: logs a CareEntry, re-anchors the reminder,
//  stays visible and checked (never hidden) once given.
//

import SwiftUI
import SwiftData

struct GiveDoseButton: View {
    let schedule: MedicationSchedule
    let dog: CaughtDog
    let given: Bool
    var onLogged: () -> Void = {}

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            giveDose()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(given ? DoggoColor.statusDoneAccent : DoggoColor.marigold)
                .frame(width: 34, height: 34)
                .background(given ? DoggoColor.statusDoneBg : Color.clear, in: Circle())
                .overlay(
                    Circle().stroke(given ? Color.clear : DoggoColor.marigold, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(given)
    }

    private func giveDose() {
        let entry = CareEntry(type: .medicated, note: "\(schedule.drugName) \u{00B7} \(schedule.dosage)", dog: dog)
        entry.scheduleId = schedule.id
        modelContext.insert(entry)
        try? modelContext.save()
        // Archiving a ward already cancels its reminders (CardDetailView.
        // archiveWard) — don't let a dose logged afterward (the Dossier
        // stays reachable for past wards) silently resurrect one.
        if dog.isActiveWard {
            MedicationReminder.reanchor(schedule, dogName: dog.name)
        }
        onLogged()
    }
}
