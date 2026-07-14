//
//  WardsListView.swift
//  DoggoCollector
//
//  B5 — replaces Collection's grid when the "Guardian Wards" tab is active.
//

import SwiftUI

struct WardsListView: View {
    let catches: [CaughtDog]

    private var activeWards: [CaughtDog] {
        catches.filter(\.isActiveWard)
    }

    private var hasPastWards: Bool {
        catches.contains { $0.isWard && $0.wardStatus != .active }
    }

    private var hasAnyActiveSchedule: Bool {
        TodaysCare.hasAnyActiveSchedule(in: catches)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            if hasAnyActiveSchedule {
                NavigationLink(value: TodaysCareDestination()) {
                    Text("Today's Care \u{2192}")
                        .font(DoggoTextStyle.bodySemibold)
                        .underline()
                        .foregroundStyle(DoggoColor.marigold)
                }
                .buttonStyle(.plain)
            }

            if activeWards.isEmpty {
                emptyState
            } else {
                ForEach(activeWards) { dog in
                    NavigationLink(value: dog) {
                        wardRow(dog)
                    }
                    .buttonStyle(.plain)
                }
            }

            if hasPastWards {
                NavigationLink(value: PastWardsDestination()) {
                    Text("View Past Wards \u{2192}")
                        .font(DoggoTextStyle.bodySemibold)
                        .underline()
                        .foregroundStyle(DoggoColor.marigold)
                }
                .buttonStyle(.plain)
                .padding(.top, DoggoSpacing.xs)
            }
        }
    }

    private func wardRow(_ dog: CaughtDog) -> some View {
        HStack(spacing: DoggoSpacing.md) {
            thumbnail(dog)
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Text("\(dog.locationLabel) \u{00B7} \(lastLogText(dog))")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
            StatusBadge.Compact(status: dog.sterilization)
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    private func thumbnail(_ dog: CaughtDog) -> some View {
        Group {
            if let image = dog.imageData.flatMap(UIImage.init) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.control))
                    .contentShape(Rectangle())
            } else {
                PolkaDotPlaceholder(seed: dog.id.hashValue)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DoggoRadius.control))
            }
        }
    }

    private func lastLogText(_ dog: CaughtDog) -> String {
        guard let latest = dog.sortedCareEntries.first else { return "no logs yet" }
        return "\(latest.type.title.lowercased()) \(latest.timestamp.formatted(.relative(presentation: .named)))"
    }

    private var emptyState: some View {
        VStack(spacing: DoggoSpacing.md) {
            ScoutMascot(expression: .idle, size: 80)
                .opacity(0.8)
            Text("No active wards right now.")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DoggoSpacing.xxl)
    }
}
