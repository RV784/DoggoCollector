//
//  MedicationsSection.swift
//  DoggoCollector
//
//  Rendered in GuardianDossierView between clinicRow and timelineSection.
//  The give-dose button is the hero interaction — one tap logs a CareEntry
//  and re-anchors the reminder; a missed/late dose is simply visible as a
//  gap in the Care Timeline below, never back-filled or flagged.
//

import SwiftUI

struct MedicationsSection: View {
    @Bindable var dog: CaughtDog
    var onToast: (String) -> Void = { _ in }

    @State private var showAddSheet = false
    @State private var editingSchedule: MedicationSchedule?

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            header
            if dog.activeMedicationSchedules.isEmpty {
                emptyState
            } else {
                VStack(spacing: DoggoSpacing.sm) {
                    ForEach(dog.activeMedicationSchedules) { schedule in
                        scheduleRow(schedule)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet(dog: dog, onToast: onToast)
        }
        .sheet(item: $editingSchedule) { schedule in
            AddMedicationSheet(dog: dog, editing: schedule, onToast: onToast)
        }
    }

    private var header: some View {
        HStack {
            Text("MEDICATIONS")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            Spacer()
            if !dog.activeMedicationSchedules.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    Text("+ Add")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(DoggoColor.marigold)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack {
                Text("Track a medication")
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DoggoColor.marigold)
            }
            .padding(DoggoSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(DoggoColor.dashedBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    /// The tappable "edit" region is a sibling Button next to
    /// GiveDoseButton, not a row-level `.onTapGesture` wrapping a nested
    /// Button — this codebase has no existing precedent for that
    /// composition, and CLAUDE.md documents a prior real bug from an
    /// oversized/ambiguous hit region stealing taps from sibling controls.
    /// Two independent sibling buttons is the pattern already used
    /// elsewhere (e.g. CardDetailView's Rename/Edit-breed row).
    private func scheduleRow(_ schedule: MedicationSchedule) -> some View {
        let entries = dog.careEntries ?? []
        let due = schedule.nextDueDate(in: entries)
        let given = schedule.isCurrentlyGiven(in: entries)
        let due_ = nextDueText(due)

        return HStack(spacing: DoggoSpacing.md) {
            Button {
                editingSchedule = schedule
            } label: {
                HStack(spacing: DoggoSpacing.md) {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(DoggoColor.logMedFg)
                        .frame(width: 36, height: 36)
                        .background(DoggoColor.logMedBg, in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(schedule.drugName)
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(DoggoColor.ink)
                        Text(schedule.dosage)
                            .font(DoggoTextStyle.caption)
                            .foregroundStyle(DoggoColor.inkMuted)
                    }

                    Spacer(minLength: DoggoSpacing.sm)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("NEXT")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(DoggoColor.metadataLabel)
                        Text(due_.text)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(due_.isOverdue ? DoggoColor.logInjuryFg : DoggoColor.ink)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GiveDoseButton(schedule: schedule, dog: dog, given: given) {
                onToast("Dose logged \u{2713}")
            }
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func nextDueText(_ date: Date) -> (text: String, isOverdue: Bool) {
        let now = Date.now
        if date <= now {
            return ("now", true)
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return (date.formatted(date: .omitted, time: .shortened), false)
        } else if calendar.isDateInTomorrow(date) {
            return ("Tomorrow \(date.formatted(date: .omitted, time: .shortened))", false)
        } else {
            return (date.formatted(.dateTime.weekday(.abbreviated).hour().minute()), false)
        }
    }
}
