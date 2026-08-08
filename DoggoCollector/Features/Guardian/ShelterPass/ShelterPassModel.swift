//
//  ShelterPassModel.swift
//  DoggoCollector
//
//  Flattens a CaughtDog (+ guardian handle + an optional AI age bracket) into
//  exactly the fields the Shelter Pass shows — so the Living Pass (screen) and
//  the Artifact (print) read one prepared value, and each state is trivial to
//  drive and preview. Derivations that the raw model doesn't store directly
//  (vaccination from the care log, sterilization label/glyph, the handover
//  note, the "+N more" collapse) happen once, here.
//
//  See shelter_pass_redesign_implementation.md and Shelter Pass.dc.html.
//

import Foundation

struct ShelterPassModel {
    struct Med: Identifiable {
        let id: UUID
        let name: String
        let dose: String
        let freq: String
        let since: String
    }
    struct LogRow: Identifiable {
        let id: UUID
        let glyph: String        // SF Symbol
        let title: String
        let sub: String          // note (may be empty)
        let whenShort: String    // "3 Jul"
        let kind: String         // "FED" — uppercased, for the print ledger
        let date: Date           // for the print ledger's range + grouping
    }

    var name: String
    var serialDisplay: String        // "#014"
    var issuedDate: Date
    var breed: String
    var breedEstimated: Bool         // EST. vs OBS.
    var age: String?                 // "≈ Adult" — nil omits the cell
    var sex: String?                 // "Female"/"Male" — nil omits the cell
    var territory: String
    var handle: String               // "@rajat"
    var sterLabel: String
    var sterKnown: Bool              // unknown → calm treatment, no tick
    var sterDone: Bool               // spayed/neutered → green tick
    var vaxLabel: String
    var vaxDone: Bool
    var clinicName: String?
    var clinicAddr: String?
    var clinicPhone: String?
    var medications: [Med]
    var careLog: [LogRow]            // full, sorted newest-first
    var logCount: Int
    var recordCount: Int
    var handoverNote: String?
    var photoData: Data?
    var photoCacheKey: String

    /// How many care rows the screen timeline shows before the "+N more" line.
    static let screenLogLimit = 5
    /// How many print ledger rows before the collapsed summary line.
    static let printLedgerLimit = 4

    var hasClinic: Bool { (clinicName?.isEmpty == false) }
    var moreLabel: String? {
        let extra = logCount - min(careLog.count, Self.screenLogLimit)
        return extra > 0 ? "+ \(extra) earlier \(extra == 1 ? "entry" : "entries")" : nil
    }

    // MARK: Build from a real dog

    static func make(dog: CaughtDog, username: String, age: String?) -> ShelterPassModel {
        let entries = dog.sortedCareEntries

        // Vaccination: derived from the most recent logged "Vaccinated" entry.
        let lastVax = entries.first { $0.type == .vaccinated }
        let vaxLabel: String
        let vaxDone: Bool
        if let lastVax {
            vaxLabel = "Last dose \u{00B7} \(shortDate(lastVax.timestamp))"
            vaxDone = true
        } else {
            vaxLabel = "Not recorded"
            vaxDone = false
        }

        // Sterilization label/glyph from the stored status (no date stored).
        let sterLabel: String
        let sterKnown: Bool
        let sterDone: Bool
        switch dog.sterilization {
        case .done:    sterLabel = "Spayed / Neutered"; sterKnown = true;  sterDone = true
        case .notYet:  sterLabel = "Not yet";           sterKnown = true;  sterDone = false
        case .unknown: sterLabel = "Unknown";           sterKnown = false; sterDone = false
        }

        let meds = dog.activeMedicationSchedules.map { s in
            Med(
                id: s.id,
                name: s.drugName,
                dose: s.dosage.isEmpty ? "—" : s.dosage,
                freq: "every \(s.frequencyHours)h",
                since: "since \(shortDate(s.startDate))"
            )
        }

        let log = entries.map { e in
            LogRow(
                id: e.id,
                glyph: e.type.icon,
                title: e.type.title,
                sub: e.note,
                whenShort: shortDate(e.timestamp),
                kind: e.type.title.uppercased(),
                date: e.timestamp
            )
        }

        let handoverNote: String? = dog.wardStatus == .handedOver
            ? "Care continued by another guardian. Nothing in this record was removed."
            : nil

        let sexDisplay: String? = {
            guard let s = dog.sex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }()

        return ShelterPassModel(
            name: dog.name,
            serialDisplay: "#" + String(format: "%03d", dog.serialNumber),
            issuedDate: dog.shelterPassIssuedAt ?? .now,
            breed: dog.breedLabel.isEmpty ? "Indie mix" : dog.breedLabel,
            breedEstimated: !dog.breedUserEdited,
            age: age,
            sex: sexDisplay,
            territory: dog.locationLabel.isEmpty ? "Somewhere nearby" : dog.locationLabel,
            handle: "@\(username)",
            sterLabel: sterLabel,
            sterKnown: sterKnown,
            sterDone: sterDone,
            vaxLabel: vaxLabel,
            vaxDone: vaxDone,
            clinicName: dog.assignedClinicName,
            clinicAddr: dog.assignedClinicAddress,
            clinicPhone: dog.assignedClinicPhone,
            medications: meds,
            careLog: log,
            logCount: log.count,
            recordCount: dog.medicalRecords?.count ?? 0,
            handoverNote: handoverNote,
            photoData: dog.coverImageData,
            photoCacheKey: dog.coverCacheKey
        )
    }

    static func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated))
    }
    var issuedDisplay: String {
        issuedDate.formatted(.dateTime.day().month(.abbreviated).year()).uppercased()
    }
}
