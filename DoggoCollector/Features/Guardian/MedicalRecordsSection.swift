//
//  MedicalRecordsSection.swift
//  DoggoCollector
//
//  Below Medications, above Care Timeline. Collapsed by default — a
//  horizontal strip when expanded, never a tall vertical list, so a
//  well-documented ward's dossier doesn't balloon in height.
//

import SwiftUI

struct MedicalRecordsSection: View {
    @Bindable var dog: CaughtDog
    var onToast: (String) -> Void = { _ in }

    @State private var isExpanded = false
    @State private var showAddSheet = false
    @State private var previewingRecord: MedicalRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            header
            if isExpanded {
                strip
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMedicalRecordSheet(dog: dog, onToast: onToast)
        }
        .fullScreenCover(item: $previewingRecord) { record in
            RecordPreviewController(record: record)
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack {
                Text("MEDICAL RECORDS (\(dog.sortedMedicalRecords.count))")
                    .font(DoggoTextStyle.eyebrow)
                    .foregroundStyle(DoggoColor.inkMuted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DoggoColor.inkMuted)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DoggoSpacing.sm) {
                ForEach(dog.sortedMedicalRecords) { record in
                    Button {
                        previewingRecord = record
                    } label: {
                        recordTile(record)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showAddSheet = true
                } label: {
                    addTile
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recordTile(_ record: MedicalRecord) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            thumbnail(record)
                .frame(width: 92, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(record.recordType)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(DoggoColor.ink)
                .lineLimit(2)
            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .frame(width: 92, alignment: .leading)
    }

    @ViewBuilder
    private func thumbnail(_ record: MedicalRecord) -> some View {
        if let first = record.sortedAttachments.first, !first.isPDF, let image = UIImage(data: first.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                DoggoColor.chipCream
                Text(record.typeGlyph)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(DoggoColor.inkMuted)
            }
        }
    }

    private var addTile: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(DoggoColor.dashedBorder, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .frame(width: 92, height: 78)
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DoggoColor.marigold)
            }
    }
}
