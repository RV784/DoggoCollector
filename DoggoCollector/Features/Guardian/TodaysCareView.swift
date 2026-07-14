//
//  TodaysCareView.swift
//  DoggoCollector
//
//  A cross-dog dashboard of every dose due today, across all wards — the
//  day read as a timeline, not a per-dog to-do list. Reached from Pack
//  home's entry chip (only when something's due) or Wards tab's quiet
//  "Today's Care →" link (always present once any schedule exists).
//

import SwiftUI
import SwiftData

/// One row in the day's timeline — a schedule paired with the dog it
/// belongs to and the moment (due or given) it should sort/display by.
/// Shared between this view and Pack home's entry-chip count.
struct TodaysCareRow: Identifiable {
    enum State { case upcoming, dueNow, overdue, givenToday }

    let schedule: MedicationSchedule
    let dog: CaughtDog
    let anchorDate: Date
    let state: State

    var id: String { schedule.notificationIdentifier }
}

enum TodaysCare {
    /// Every active schedule across every active ward, resolved to today's
    /// timeline: doses already given today keep their given-time slot;
    /// doses still owed are included if due today, or overdue from before
    /// today (which clamps in as `.overdue`, sorted to the top).
    static func rows(for catches: [CaughtDog]) -> [TodaysCareRow] {
        let now = Date.now
        let startOfToday = Calendar.current.startOfDay(for: now)
        var result: [TodaysCareRow] = []

        for dog in catches where dog.isActiveWard {
            let entries = dog.careEntries ?? []
            for schedule in dog.activeMedicationSchedules {
                let lastDose = schedule.lastDose(in: entries)
                let due = schedule.nextDueDate(after: lastDose?.timestamp)

                // schedule.isCurrentlyGiven(in:) is the same check, inlined
                // here since lastDose/due are already in hand — kept in
                // sync with MedicationsSection's own "given" state via that
                // single shared method, not a second independent rule.
                if let lastDose, due > now {
                    // Still covered, but only relevant to *today's*
                    // timeline if the covering dose was actually given
                    // today — a dose given yesterday on a >24h schedule has
                    // nothing to report for today specifically.
                    guard Calendar.current.isDateInToday(lastDose.timestamp) else { continue }
                    result.append(TodaysCareRow(schedule: schedule, dog: dog, anchorDate: lastDose.timestamp, state: .givenToday))
                    continue
                }

                guard due < startOfToday || Calendar.current.isDateInToday(due) else { continue }
                let state: TodaysCareRow.State = due < startOfToday ? .overdue : (due <= now ? .dueNow : .upcoming)
                result.append(TodaysCareRow(schedule: schedule, dog: dog, anchorDate: due, state: state))
            }
        }

        return result.sorted { $0.anchorDate < $1.anchorDate }
    }

    static func dueTodayCount(for catches: [CaughtDog]) -> Int {
        rows(for: catches).filter { $0.state == .dueNow || $0.state == .overdue }.count
    }

    static func hasAnyActiveSchedule(in catches: [CaughtDog]) -> Bool {
        catches.contains { $0.isActiveWard && !$0.activeMedicationSchedules.isEmpty }
    }
}

struct TodaysCareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    @State private var toastMessage: String?

    private var rows: [TodaysCareRow] {
        TodaysCare.rows(for: catches)
    }

    private var allGiven: Bool {
        !rows.isEmpty && rows.allSatisfy { $0.state == .givenToday }
    }

    var body: some View {
        ZStack {
            DoggoColor.sheetCream.ignoresSafeArea()

            if rows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: DoggoSpacing.lg) {
                        if allGiven {
                            allDoneBanner
                        }
                        VStack(spacing: DoggoSpacing.sm) {
                            ForEach(rows) { row in
                                rowView(row)
                            }
                        }
                    }
                    .padding(DoggoSpacing.lg)
                }
            }
        }
        .toast(message: $toastMessage)
        .navigationTitle("Today's Care")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(DoggoColor.ink)
                }
            }
        }
    }

    private var allDoneBanner: some View {
        VStack(spacing: DoggoSpacing.sm) {
            ScoutMascot(expression: .happy, size: 90)
            Text("Everyone's taken care of today")
                .font(DoggoTextStyle.headline)
                .foregroundStyle(DoggoColor.ink)
            Text("Every dose, given. That's a good day.")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .multilineTextAlignment(.center)
        .padding(.top, DoggoSpacing.lg)
        .padding(.bottom, DoggoSpacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: DoggoSpacing.md) {
            ScoutMascot(expression: .idle, size: 100)
                .floatingIdle()
            VStack(spacing: DoggoSpacing.xs) {
                Text("Nothing scheduled yet")
                    .font(DoggoTextStyle.headline)
                    .foregroundStyle(DoggoColor.ink)
                Text("Track a medication from any ward's Dossier and it'll show up here, across all your wards.")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DoggoSpacing.xxl)
    }

    private func rowView(_ row: TodaysCareRow) -> some View {
        HStack(spacing: DoggoSpacing.md) {
            Text(row.anchorDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(row.state == .overdue ? DoggoColor.logInjuryFg : DoggoColor.ink)
                .frame(width: 52, alignment: .leading)

            avatar(row.dog)
                .frame(width: 34, height: 34)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.dog.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DoggoColor.ink)
                Text("\(row.schedule.drugName) \u{00B7} \(row.schedule.dosage)")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: DoggoSpacing.sm)

            GiveDoseButton(schedule: row.schedule, dog: row.dog, given: row.state == .givenToday) {
                toastMessage = "Dose logged \u{2713}"
            }
        }
        .padding(DoggoSpacing.md)
        .background(rowBackground(row.state), in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DoggoRadius.control)
                .stroke(rowBorder(row.state), lineWidth: 1)
        )
    }

    private func rowBackground(_ state: TodaysCareRow.State) -> Color {
        switch state {
        case .dueNow: DoggoColor.statusAttnBg
        case .overdue: DoggoColor.logInjuryBg
        case .upcoming, .givenToday: DoggoColor.cardWhite
        }
    }

    private func rowBorder(_ state: TodaysCareRow.State) -> Color {
        switch state {
        case .dueNow: DoggoColor.statusAttnBorder
        default: Color.clear
        }
    }

    @ViewBuilder
    private func avatar(_ dog: CaughtDog) -> some View {
        if let image = dog.imageData.flatMap(UIImage.init) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            PolkaDotPlaceholder(seed: dog.id.hashValue)
        }
    }
}
