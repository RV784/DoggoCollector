//
//  AddMedicalRecordSheet.swift
//  DoggoCollector
//
//  Two steps in one sheet: pick photos/PDFs, then file them under a type +
//  date. No delete flow this pass — records are small enough that a
//  mis-added one can wait for a future edit pass (see the plan's §7).
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddMedicalRecordSheet: View {
    let dog: CaughtDog
    var onToast: (String) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Step { case pick, details }
    private struct PendingAttachment {
        let data: Data
        let filename: String
        let isPDF: Bool
    }

    @State private var step: Step = .pick
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var showFileImporter = false
    @State private var recordType = "Other"
    @State private var date = Date.now
    @State private var notes = ""

    private let recordTypes = ["Blood Test", "X-Ray", "Prescription", "Other"]

    var body: some View {
        Group {
            switch step {
            case .pick: pickStep
            case .details: detailsStep
            }
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                loadFiles(urls)
            }
        }
        .onChange(of: photosPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPhotos(newItems) }
        }
    }

    // MARK: - Pick step

    private var pickStep: some View {
        VStack(spacing: DoggoSpacing.xl) {
            VStack(spacing: DoggoSpacing.xs) {
                Text("Add medical record")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                Text("Photos of printouts, or PDFs from the clinic")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            .padding(.top, DoggoSpacing.lg)

            HStack(spacing: DoggoSpacing.md) {
                PhotosPicker(selection: $photosPickerItems, maxSelectionCount: nil, matching: .images) {
                    pickTile(icon: "photo.on.rectangle", bg: DoggoColor.recordPhotoBg, fg: DoggoColor.recordPhotoFg, title: "Photo library")
                }

                Button {
                    showFileImporter = true
                } label: {
                    pickTile(icon: "doc.fill", bg: DoggoColor.recordFileBg, fg: DoggoColor.recordFileFg, title: "Files (PDF)")
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(DoggoSpacing.xl)
    }

    private func pickTile(icon: String, bg: Color, fg: Color, title: String) -> some View {
        VStack(spacing: DoggoSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 44, height: 44)
                .background(bg, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            Text(title)
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DoggoSpacing.lg)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DoggoColor.chipCream, lineWidth: 2)
        )
    }

    // MARK: - Details step

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: DoggoSpacing.lg) {
                confirmationStrip
                typeChips
                dateField
                LabeledInputField(label: "NOTES (optional)", placeholder: "e.g. follow-up in 2 weeks", text: $notes)
                PillButton(title: "Save record", action: save)
            }
            .padding(DoggoSpacing.xl)
        }
    }

    private var confirmationStrip: some View {
        HStack(spacing: DoggoSpacing.md) {
            Image(systemName: "checkmark")
                .foregroundStyle(DoggoColor.statusDoneAccent)
                .frame(width: 36, height: 36)
                .background(DoggoColor.statusDoneBg, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            Text("\(pendingAttachments.count) photos/files attached")
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
            Spacer(minLength: 0)
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.sheetCream, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private var typeChips: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text("TYPE")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            FlowLayout(spacing: DoggoSpacing.sm) {
                ForEach(recordTypes, id: \.self) { type in
                    Button {
                        recordType = type
                    } label: {
                        Text(type)
                            .font(DoggoTextStyle.caption)
                            .foregroundStyle(recordType == type ? .white : DoggoColor.ink)
                            .padding(.horizontal, DoggoSpacing.md)
                            .padding(.vertical, DoggoSpacing.xs + 2)
                            .background(recordType == type ? DoggoColor.marigold : DoggoColor.cardWhite, in: Capsule())
                            .overlay(
                                Capsule().stroke(recordType == type ? Color.clear : DoggoColor.chipCream, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text("DATE")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)
            DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(DoggoColor.marigold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let filename = "photo-\(UUID().uuidString).jpg"
            pendingAttachments.append(PendingAttachment(data: data, filename: filename, isPDF: false))
        }
        photosPickerItems = []
        if !pendingAttachments.isEmpty {
            withAnimation { step = .details }
        }
    }

    /// Imported file URLs are security-scoped — must bracket the read with
    /// start/stopAccessingSecurityScopedResource.
    private func loadFiles(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            pendingAttachments.append(PendingAttachment(data: data, filename: url.lastPathComponent, isPDF: true))
        }
        if !pendingAttachments.isEmpty {
            withAnimation { step = .details }
        }
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = MedicalRecord(recordType: recordType, date: date, notes: trimmedNotes.isEmpty ? nil : trimmedNotes, dog: dog)
        modelContext.insert(record)
        for (index, pending) in pendingAttachments.enumerated() {
            let attachment = MedicalAttachment(
                data: pending.data,
                filename: pending.filename,
                isPDF: pending.isPDF,
                sortIndex: index,
                record: record
            )
            modelContext.insert(attachment)
        }
        try? modelContext.save()
        dismiss()
        onToast("Record saved \u{2713}")
    }
}

/// Minimal wrapping chip row — the app has no existing flow-layout
/// component, and this is the only place one's needed (4 short type chips
/// that may or may not fit one line depending on device width).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
