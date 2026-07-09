//
//  GuardianDossierView.swift
//  DoggoCollector
//
//  B2 — the Guardian Dossier tab on Card Detail. Rendered inside
//  CardDetailView's existing ScrollView, wards only.
//

import SwiftUI

struct GuardianDossierView: View {
    @Bindable var dog: CaughtDog

    @State private var showStatusDialog = false
    @State private var showDietaryEdit = false
    @State private var dietaryText = ""
    @State private var showQuirksEdit = false
    @State private var quirksText = ""
    @State private var showClinicSheet = false

    private var lastCareCheckText: String {
        guard let latest = dog.sortedCareEntries.first else { return "No checks yet" }
        return latest.timestamp.formatted(.relative(presentation: .named))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xl) {
            statusSection
            vitalsSection
            if dog.assignedClinicName != nil {
                clinicRow
            }
            timelineSection
        }
        .confirmationDialog("Update \(dog.name)'s status", isPresented: $showStatusDialog, titleVisibility: .visible) {
            Button("Sterilized & vaccinated") { dog.sterilization = .done }
            Button("Not yet sterilized") { dog.sterilization = .notYet }
            Button("Status unknown") { dog.sterilization = .unknown }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Dietary profile", isPresented: $showDietaryEdit) {
            TextField("e.g. Rice + chicken, no bones", text: $dietaryText)
            Button("Save") { dog.dietaryProfile = dietaryText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Behavioral quirks", isPresented: $showQuirksEdit) {
            TextField("e.g. Shy around men, loves belly rubs", text: $quirksText)
            Button("Save") { dog.behavioralQuirks = quirksText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showClinicSheet) {
            ClinicSheet(dog: dog)
        }
    }

    private var statusSection: some View {
        Button {
            showStatusDialog = true
        } label: {
            StatusBadge(status: dog.sterilization)
        }
        .buttonStyle(.plain)
    }

    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            Text("VITALS")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)

            Grid(horizontalSpacing: DoggoSpacing.md, verticalSpacing: DoggoSpacing.md) {
                GridRow {
                    vitalCell(label: "DIETARY PROFILE", value: dog.dietaryProfile ?? "Tap to add") {
                        dietaryText = dog.dietaryProfile ?? ""
                        showDietaryEdit = true
                    }
                    vitalCell(label: "BEHAVIORAL QUIRKS", value: dog.behavioralQuirks ?? "Tap to add") {
                        quirksText = dog.behavioralQuirks ?? ""
                        showQuirksEdit = true
                    }
                }
                GridRow {
                    vitalCell(label: "ASSIGNED CLINIC", value: dog.assignedClinicName ?? "None nearby yet")
                    vitalCell(label: "LAST CARE CHECK", value: lastCareCheckText)
                }
            }
        }
    }

    private func vitalCell(label: String, value: String, action: (() -> Void)? = nil) -> some View {
        let cell = VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            Text(value)
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
                .lineLimit(2)
        }
        .padding(DoggoSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))

        return Group {
            if let action {
                Button(action: action) { cell }
                    .buttonStyle(.plain)
            } else {
                cell
            }
        }
    }

    private var clinicRow: some View {
        Button {
            showClinicSheet = true
        } label: {
            HStack(spacing: DoggoSpacing.md) {
                Image(systemName: "phone.fill")
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(DoggoColor.marigold, in: Circle())
                Text("Call \(dog.name)'s clinic")
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            .padding(DoggoSpacing.md)
            .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        }
        .buttonStyle(.plain)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            Text("CARE TIMELINE")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)

            if dog.sortedCareEntries.isEmpty {
                Text("Nothing logged yet — tap Log Interaction when you feed or check on \(dog.name).")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .padding(DoggoSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DoggoColor.chipCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            } else {
                VStack(spacing: DoggoSpacing.sm) {
                    ForEach(dog.sortedCareEntries) { entry in
                        careEntryRow(entry)
                    }
                }
            }
        }
    }

    private func careEntryRow(_ entry: CareEntry) -> some View {
        HStack(spacing: DoggoSpacing.md) {
            Image(systemName: entry.type.icon)
                .foregroundStyle(entry.type.fg)
                .frame(width: 40, height: 40)
                .background(entry.type.bg, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.type.title)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
            }
            Spacer()
            Text(entry.timestamp.formatted(.relative(presentation: .named)))
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
