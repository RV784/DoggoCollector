//
//  PastWardsView.swift
//  DoggoCollector
//
//  B6 — reached through the Wards tab, not deleted from anywhere. Dossiers
//  are never deleted; lifecycle changes only soft-archive here.
//

import SwiftUI
import SwiftData

struct PastWardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    private var pastWards: [CaughtDog] {
        catches.filter { $0.isWard && $0.wardStatus != .active }
    }

    var body: some View {
        ZStack {
            DoggoColor.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
                topBar

                VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                    Text("Past Wards")
                        .font(DoggoTextStyle.displayMedium)
                        .foregroundStyle(DoggoColor.ink)
                    Text("Dogs you've looked after who've moved on. Their dossiers stay, always.")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                }

                ScrollView {
                    LazyVStack(spacing: DoggoSpacing.sm) {
                        ForEach(pastWards) { dog in
                            NavigationLink(value: dog) {
                                row(dog)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, DoggoSpacing.lg)
                }
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
            .buttonStyle(ScalePressButtonStyle())
            Spacer()
        }
    }

    private func row(_ dog: CaughtDog) -> some View {
        HStack(spacing: DoggoSpacing.md) {
            thumbnail(dog)
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Text(dog.locationLabel)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
            TagChip(text: dog.wardStatus.displayTitle)
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .opacity(0.85)
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
}
