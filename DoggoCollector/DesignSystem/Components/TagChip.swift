//
//  TagChip.swift
//  DoggoCollector
//

import SwiftUI

/// Small trait/breed/distance-style tag, per the design brief's
/// "horizontal chip row for quick facts" reference.
struct TagChip: View {
    var text: String
    var prominent: Bool = false

    var body: some View {
        Text(text)
            .font(DoggoTextStyle.caption)
            .foregroundStyle(prominent ? .white : DoggoColor.ink)
            .padding(.horizontal, DoggoSpacing.md)
            .padding(.vertical, DoggoSpacing.xs + 2)
            .background(prominent ? DoggoColor.marigold : DoggoColor.chipCream, in: Capsule())
    }
}

/// Filterable stat pill used on the Collection screen ("1 caught" / "1 breeds" / "1 today").
struct StatChip: View {
    var text: String
    var isActive: Bool

    var body: some View {
        Text(text)
            .font(DoggoTextStyle.bodySemibold)
            .foregroundStyle(isActive ? .white : DoggoColor.ink)
            .padding(.horizontal, DoggoSpacing.lg)
            .padding(.vertical, DoggoSpacing.sm + 2)
            .background(isActive ? DoggoColor.marigold : DoggoColor.cardWhite, in: Capsule())
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            TagChip(text: "Goofball")
            TagChip(text: "Fluffy")
            TagChip(text: "2.6 km")
        }
        HStack {
            StatChip(text: "1 caught", isActive: true)
            StatChip(text: "1 breeds", isActive: false)
            StatChip(text: "1 today", isActive: false)
        }
    }
    .padding()
    .background(DoggoColor.cream)
}
