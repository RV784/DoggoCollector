//
//  AddMedicationSheet.swift
//  DoggoCollector
//
//  Track a medication (and, via `editing`, correct or end one). A first-ever
//  save chains to a Scout-framed notification permission ask as a second
//  step of the same sheet, rather than a separate sheet-from-sheet — see
//  GuardianDossierView's pendingClinicPicker for why that dance is avoided
//  here. `dosage` is always free text, never suggested — the one hard
//  product line this whole feature is built around.
//

import SwiftUI
import SwiftData

struct AddMedicationSheet: View {
    let dog: CaughtDog
    var editing: MedicationSchedule? = nil
    var onToast: (String) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenMedNotifAsk") private var hasSeenMedNotifAsk = false

    private enum Step { case form, notifAsk }

    @State private var step: Step = .form
    @State private var drugName = ""
    @State private var dosage = ""
    @State private var frequencyHours = 12
    @State private var startDate = Date.now
    @State private var isOngoing = true
    @State private var endDate = Date.now
    @State private var notes = ""
    @State private var savedSchedule: MedicationSchedule?
    @FocusState private var drugNameFocused: Bool

    private var isEditing: Bool { editing != nil }

    private var canSave: Bool {
        !drugName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var typeaheadMatches: [DrugNameEntry] {
        DrugNameDirectory.matches(for: drugName)
    }

    var body: some View {
        Group {
            switch step {
            case .form: formStep
            case .notifAsk: notifAskStep
            }
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(640)])
        .presentationDragIndicator(.visible)
        .onAppear(perform: populateIfEditing)
    }

    // MARK: - Form step

    private var formStep: some View {
        ScrollView {
            VStack(spacing: DoggoSpacing.lg) {
                VStack(spacing: DoggoSpacing.xs) {
                    Text(isEditing ? "Edit medication" : "Track a medication")
                        .font(DoggoTextStyle.headline)
                        .foregroundStyle(DoggoColor.ink)
                    Text("What the vet prescribed for \(dog.name)")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                .padding(.top, DoggoSpacing.lg)

                drugNameField
                LabeledInputField(label: "DOSAGE", placeholder: "e.g. as written on the prescription", text: $dosage)
                frequencySection
                ongoingRow
                LabeledInputField(label: "NOTES (optional)", placeholder: "e.g. follow-up in 2 weeks", text: $notes)

                PillButton(title: "Save schedule", action: save)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)

                if isEditing, editing?.isActive == true {
                    TextLinkButton(title: "End this course", color: DoggoColor.logInjuryFg, action: endCourse)
                }
            }
            .padding(DoggoSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var drugNameField: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text("DRUG NAME")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            TextField("Start typing a name\u{2026}", text: $drugName)
                .font(DoggoTextStyle.bodyRegular)
                .autocorrectionDisabled()
                .focused($drugNameFocused)
                .padding(DoggoSpacing.md)
                .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DoggoColor.inputBorder, lineWidth: 2)
                )

            if drugNameFocused, drugName.count >= 2, !typeaheadMatches.isEmpty {
                typeaheadDropdown
            }
        }
    }

    private var typeaheadDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(typeaheadMatches.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                }
                Button {
                    drugName = entry.name
                    drugNameFocused = false
                } label: {
                    HStack(spacing: DoggoSpacing.xs) {
                        Text(entry.name)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(DoggoColor.ink)
                        Text(entry.activeIngredient)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(DoggoColor.inkMuted)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DoggoSpacing.md)
                    .padding(.vertical, DoggoSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text("EVERY \u{2014} HOURS")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            HStack {
                stepperButton(systemName: "minus") { frequencyHours = max(4, frequencyHours - 2) }
                Spacer()
                Text("\(frequencyHours) hrs")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(DoggoColor.ink)
                    .frame(minWidth: 90)
                Spacer()
                stepperButton(systemName: "plus") { frequencyHours = min(48, frequencyHours + 2) }
            }
            .padding(DoggoSpacing.lg)
            .background(DoggoColor.sheetCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DoggoColor.ink)
                .frame(width: 38, height: 38)
                .background(DoggoColor.cardWhite, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var ongoingRow: some View {
        VStack(spacing: DoggoSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ongoing")
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(DoggoColor.ink)
                    Text("No end date")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                Spacer()
                CapsuleToggle(isOn: $isOngoing)
            }
            if !isOngoing {
                DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(DoggoTextStyle.bodyRegular)
                    .tint(DoggoColor.marigold)
            }
        }
        .padding(DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DoggoRadius.control)
                .stroke(DoggoColor.chipCream, lineWidth: 1.5)
        )
    }

    // MARK: - Notification-ask step

    private var notifAskStep: some View {
        VStack(spacing: DoggoSpacing.xl) {
            Spacer()
            ScoutMascot(expression: .idle, size: 100)
                .floatingIdle()
            VStack(spacing: DoggoSpacing.sm) {
                Text("Let Scout remind you?")
                    .font(DoggoTextStyle.displayMedium)
                    .foregroundStyle(DoggoColor.ink)
                Text("A gentle nudge every \(frequencyHours) hours for \(drugName) — only for meds you track, nothing else.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
            PillButton(title: "Yes, remind me", action: acceptReminders)
            TextLinkButton(title: "Not now", color: DoggoColor.inkMuted, action: declineReminders)
            Spacer()
        }
        .padding(DoggoSpacing.xl)
    }

    // MARK: - Actions

    private func populateIfEditing() {
        guard let editing else { return }
        drugName = editing.drugName
        dosage = editing.dosage
        frequencyHours = editing.frequencyHours
        startDate = editing.startDate
        isOngoing = editing.endDate == nil
        endDate = editing.endDate ?? .now
        notes = editing.notes ?? ""
    }

    private func save() {
        let trimmedName = drugName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedDosage.isEmpty else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasEditing = isEditing

        let schedule: MedicationSchedule
        if let editing {
            editing.drugName = trimmedName
            editing.dosage = trimmedDosage
            editing.frequencyHours = frequencyHours
            editing.endDate = isOngoing ? nil : endDate
            editing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            schedule = editing
        } else {
            schedule = MedicationSchedule(
                drugName: trimmedName,
                dosage: trimmedDosage,
                frequencyHours: frequencyHours,
                startDate: startDate,
                endDate: isOngoing ? nil : endDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                dog: dog
            )
            modelContext.insert(schedule)
        }
        try? modelContext.save()
        savedSchedule = schedule

        Task {
            let status = await MedicationReminder.authorizationStatus()
            let isAuthorized = status == .authorized || status == .provisional || status == .ephemeral

            if wasEditing {
                // Frequency/name changes must re-register the notification.
                if isAuthorized { MedicationReminder.reanchor(schedule, dogName: dog.name) }
                finish(toast: "\(trimmedName) updated \u{2713}")
                return
            }

            if isAuthorized {
                MedicationReminder.reanchor(schedule, dogName: dog.name)
                finish(toast: "Scout will remind you \u{2713}")
            } else if !hasSeenMedNotifAsk {
                hasSeenMedNotifAsk = true
                withAnimation { step = .notifAsk }
            } else {
                // Denied, or already saw the ask once before — data-first:
                // save silently, the sweep picks reminders up if permission
                // ever arrives.
                finish(toast: "\(trimmedName) tracked \u{2713}")
            }
        }
    }

    private func acceptReminders() {
        guard let savedSchedule else { return }
        Task {
            let granted = await MedicationReminder.requestAuthorization()
            if granted {
                MedicationReminder.schedule(for: savedSchedule, dogName: dog.name)
            }
            finish(toast: granted ? "Scout will remind you \u{2713}" : "\(savedSchedule.drugName) tracked \u{2713}")
        }
    }

    private func declineReminders() {
        guard let savedSchedule else { return }
        finish(toast: "\(savedSchedule.drugName) tracked \u{2713}")
    }

    private func endCourse() {
        guard let editing else { return }
        editing.endDate = .now
        try? modelContext.save()
        MedicationReminder.cancel(editing)
        finish(toast: "\(editing.drugName) course ended")
    }

    private func finish(toast: String) {
        dismiss()
        onToast(toast)
    }
}

/// A small warm-palette capsule switch — the native `Toggle`'s default
/// green/blue clashes with Sunny Fetch, and this app already avoids native
/// controls in favor of bespoke ones wherever contrast/brand matters (see
/// SegmentedTabs replacing the native segmented Picker).
private struct CapsuleToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? DoggoColor.marigold : DoggoColor.chipCream)
                .frame(width: 50, height: 30)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
    }
}
