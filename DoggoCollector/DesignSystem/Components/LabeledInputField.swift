//
//  LabeledInputField.swift
//  DoggoCollector
//
//  Labeled, bordered text field shared by the medication-tracking sheets'
//  forms (AddMedicationSheet, AddMedicalRecordSheet) — one place to keep
//  the input styling in sync rather than two copy-pasted private helpers.
//

import SwiftUI

struct LabeledInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text(label)
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            TextField(placeholder, text: $text)
                .font(DoggoTextStyle.bodyRegular)
                .padding(DoggoSpacing.md)
                .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DoggoColor.inputBorder, lineWidth: 2)
                )
        }
    }
}
