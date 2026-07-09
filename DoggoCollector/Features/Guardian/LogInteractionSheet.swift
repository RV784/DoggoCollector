//
//  LogInteractionSheet.swift
//  DoggoCollector
//
//  B3 — one-tap care logging, no forms. Notes stay empty from this flow;
//  the seeded sample notes in the design prototype ("Anti-rabies booster")
//  are fake data only, not a field this sheet exposes.
//

import SwiftUI
import SwiftData

struct LogInteractionSheet: View {
    let dog: CaughtDog
    var onLogged: (CareEntryType) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: DoggoSpacing.md), GridItem(.flexible(), spacing: DoggoSpacing.md)]

    var body: some View {
        VStack(spacing: DoggoSpacing.lg) {
            VStack(spacing: DoggoSpacing.xs) {
                Text("Log Interaction")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                    .padding(.top)
                Text("One tap — that's it.")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            .padding(.top, DoggoSpacing.lg)

            LazyVGrid(columns: columns, spacing: DoggoSpacing.md) {
                ForEach(CareEntryType.allCases, id: \.self) { type in
                    tile(type)
                }
            }
            .padding(.horizontal, DoggoSpacing.lg)

            Spacer()
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
    }

    private func tile(_ type: CareEntryType) -> some View {
        Button {
            log(type)
        } label: {
            VStack(spacing: DoggoSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(type.fg)
                    .frame(width: 56, height: 56)
                    .background(type.bg, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
                Text(type.title)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(DoggoSpacing.lg)
            .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            .overlay(alignment: .topTrailing) {
                if type == .vaccinated {
                    Text("TRACKED")
                        .font(DoggoTextStyle.eyebrow)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DoggoSpacing.xs + 2)
                        .padding(.vertical, 2)
                        .background(DoggoColor.marigold, in: Capsule())
                        .padding(DoggoSpacing.sm)
                }
            }
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    private func log(_ type: CareEntryType) {
        let entry = CareEntry(type: type, dog: dog)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
        onLogged(type)
    }
}
