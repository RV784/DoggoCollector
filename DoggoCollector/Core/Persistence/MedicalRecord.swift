//
//  MedicalRecord.swift
//  DoggoCollector
//
//  A vet visit's paperwork — one or more photo/PDF attachments filed under a
//  type + date. Attachments are their own @Model (not a coded [Data] blob)
//  so SwiftData's .externalStorage sits on each attachment's own Data.
//

import Foundation
import SwiftData

@Model
final class MedicalRecord {
    var id: UUID = UUID()
    /// Open string ("Blood Test"/"X-Ray"/"Prescription"/"Other"/anything) —
    /// deliberately not a closed enum, matching the typeahead's "free text
    /// always wins" philosophy.
    var recordType: String = "Other"
    var date: Date = Date.now
    var notes: String? = nil
    /// Model-only this pass — the field exists for a future "link this
    /// record to the Injury Check that led to it" UI, but no screen sets or
    /// reads it yet. Not a forgotten wire-up.
    var linkedCareEntryId: UUID? = nil
    var dog: CaughtDog? = nil
    @Relationship(deleteRule: .cascade, inverse: \MedicalAttachment.record)
    var attachments: [MedicalAttachment]? = []

    init(
        recordType: String,
        date: Date = .now,
        notes: String? = nil,
        dog: CaughtDog? = nil
    ) {
        self.id = UUID()
        self.recordType = recordType
        self.date = date
        self.notes = notes
        self.dog = dog
    }

    var sortedAttachments: [MedicalAttachment] {
        (attachments ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Short text badge, matching StatusBadge's ✓!? language — never emoji
    /// or a medical icon, per the design.
    var typeGlyph: String {
        switch recordType {
        case "Blood Test": "B"
        case "X-Ray": "X"
        case "Prescription": "Rx"
        default: "\u{2022}"
        }
    }
}

@Model
final class MedicalAttachment {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data = Data()
    /// Original filename where known, else generated — needed for
    /// QuickLook's temp-file extension.
    var filename: String = "attachment"
    var isPDF: Bool = false
    var sortIndex: Int = 0
    var record: MedicalRecord? = nil

    init(
        data: Data,
        filename: String = "attachment",
        isPDF: Bool = false,
        sortIndex: Int = 0,
        record: MedicalRecord? = nil
    ) {
        self.id = UUID()
        self.data = data
        self.filename = filename
        self.isPDF = isPDF
        self.sortIndex = sortIndex
        self.record = record
    }
}
