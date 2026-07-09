//
//  StatusBadge.swift
//  DoggoCollector
//
//  Guardian Mode's one net-new component (per the spec — don't fork variants
//  into separate files). Three render styles share one `SterilizationStatus`
//  source of truth: a full badge (dossier / wards list / shelter pass), a
//  compact dot+label row (wards list), and a tiny provenance tag (shelter
//  pass EST./OBS. fields) via the nested `ProvenanceTag` view.
//

import SwiftUI

extension SterilizationStatus {
    var accentColor: Color {
        switch self {
        case .done: DoggoColor.statusDoneAccent
        case .notYet: DoggoColor.statusAttnAccent
        case .unknown: DoggoColor.inkMuted
        }
    }

    var backgroundColor: Color {
        switch self {
        case .done: DoggoColor.statusDoneBg
        case .notYet: DoggoColor.statusAttnBg
        case .unknown: DoggoColor.statusUnknownBg
        }
    }

    var borderColor: Color {
        switch self {
        case .done: DoggoColor.statusDoneBorder
        case .notYet: DoggoColor.statusAttnBorder
        case .unknown: DoggoColor.statusUnknownBorder
        }
    }

    var glyph: String {
        switch self {
        case .done: "checkmark"
        case .notYet: "exclamationmark"
        case .unknown: "questionmark"
        }
    }

    var label: String {
        switch self {
        case .done: "Sterilized & vaccinated"
        case .notYet: "Not yet sterilized"
        case .unknown: "Status unknown"
        }
    }

    var sub: String {
        switch self {
        case .done: "Confirmed at clinic"
        case .notYet: "Worth arranging soon"
        case .unknown: "Not recorded yet"
        }
    }

    /// Short "✓ Sterilized"-style label for the compact wards-list variant.
    var compactLabel: String {
        switch self {
        case .done: "✓ Sterilized"
        case .notYet: "! Not yet"
        case .unknown: "? Unknown"
        }
    }
}

/// Full badge — dossier / wards list / shelter pass.
struct StatusBadge: View {
    let status: SterilizationStatus

    var body: some View {
        HStack(spacing: DoggoSpacing.md) {
            Circle()
                .fill(status.accentColor)
                .frame(width: 8, height: 8)
            Image(systemName: status.glyph)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(status.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.label)
                    .font(DoggoTextStyle.bodySemibold)
                    .foregroundStyle(DoggoColor.ink)
                Text(status.sub)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(DoggoSpacing.md)
        .background(status.backgroundColor, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DoggoRadius.control)
                .stroke(status.borderColor, lineWidth: 1)
        )
    }

    /// Compact dot + label only, no sub — used in wards-list rows.
    struct Compact: View {
        let status: SterilizationStatus

        var body: some View {
            HStack(spacing: DoggoSpacing.xs) {
                Circle()
                    .fill(status.accentColor)
                    .frame(width: 6, height: 6)
                Text(status.compactLabel)
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(status.accentColor)
            }
            .padding(.horizontal, DoggoSpacing.sm + 2)
            .padding(.vertical, DoggoSpacing.xs)
            .background(status.backgroundColor, in: Capsule())
        }
    }

    /// Tiny uppercase provenance capsule for the Shelter Pass's EST./OBS. tags.
    enum ProvenanceKind {
        case estimated, observed

        var text: String {
            switch self {
            case .estimated: "EST."
            case .observed: "OBS."
            }
        }

        var fg: Color {
            switch self {
            case .estimated: DoggoColor.provEstFg
            case .observed: DoggoColor.provObsFg
            }
        }

        var bg: Color {
            switch self {
            case .estimated: DoggoColor.provEstBg
            case .observed: DoggoColor.provObsBg
            }
        }
    }

    struct ProvenanceTag: View {
        let kind: ProvenanceKind

        var body: some View {
            Text(kind.text)
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(kind.fg)
                .padding(.horizontal, DoggoSpacing.xs + 2)
                .padding(.vertical, 2)
                .background(kind.bg, in: Capsule())
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .done)
        StatusBadge(status: .notYet)
        StatusBadge(status: .unknown)
        HStack {
            StatusBadge.Compact(status: .done)
            StatusBadge.Compact(status: .notYet)
            StatusBadge.Compact(status: .unknown)
        }
        HStack {
            StatusBadge.ProvenanceTag(kind: .estimated)
            StatusBadge.ProvenanceTag(kind: .observed)
        }
    }
    .padding()
    .background(DoggoColor.cream)
}
