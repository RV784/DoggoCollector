//
//  InsightPanelView.swift
//  DoggoCollector
//
//  "Scout's Sniff" — auto-revealed below the card on Card Detail's appear,
//  not gated behind a tap. Breed-adjacent education only; never implies a
//  health/wellbeing assessment. See DogInsightProviding for the data source
//  (mock for now — a real Apple Intelligence-backed conformance is a planned
//  follow-up, so this view depends only on the protocol).
//

import SwiftUI

struct InsightPanelView: View {
    let dog: CaughtDog

    private let insightProvider: DogInsightProviding = FoundationModelsInsightProvider()

    @State private var insight: DogInsight?
    @State private var showBreedInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            Text("SCOUT'S SNIFF")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)

            if let insight {
                populated(insight)
                    .transition(.opacity)
            } else {
                loading
                    .transition(.opacity)
            }
        }
        .task {
            async let resolved = insightProvider.insight(for: dog)
            async let minimumDelay: ()? = try? Task.sleep(for: .milliseconds(700))
            let (result, _) = await (resolved, minimumDelay)
            withAnimation(.easeInOut(duration: 0.3)) {
                insight = result
            }
        }
    }

    private var loading: some View {
        HStack(spacing: DoggoSpacing.md) {
            ScoutMascot(expression: .curious, size: 64)
            VStack(alignment: .leading, spacing: DoggoSpacing.sm) {
                Text("Scout's having a sniff…")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                BouncingDotsView()
            }
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
    }

    @ViewBuilder
    private func populated(_ insight: DogInsight) -> some View {
        if insight.isConfident {
            confidentContent(insight)
        } else {
            lowConfidenceContent(insight)
        }
    }

    private func confidentContent(_ insight: DogInsight) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            HStack(spacing: DoggoSpacing.xs) {
                TagChip(text: "Best guess: \(insight.breedGuess)", prominent: true)
                Button {
                    showBreedInfo = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(DoggoColor.inkMuted)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showBreedInfo) {
                    Text("Scout's AI takes a guess from the photo — breeds aren't a certainty, especially for lovable street mixes.")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.ink)
                        .padding(DoggoSpacing.lg)
                        .frame(maxWidth: 260)
                        .presentationCompactAdaptation(.popover)
                }
            }

            TagChip(text: insight.ageBracket.rawValue)

            careTipsSection(insight.careTips)
            didYouKnowSection(insight.didYouKnowFact)
            findCareLink
        }
    }

    private func lowConfidenceContent(_ insight: DogInsight) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.md) {
            Text("Scout's stumped on this one — still a very good dog.")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.ink)

            TagChip(text: insight.ageBracket.rawValue)

            careTipsSection(insight.careTips)
            findCareLink
        }
    }

    private func careTipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.sm) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: DoggoSpacing.sm) {
                    Text("🐾")
                    Text(tip)
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.ink)
                }
                .padding(DoggoSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
            }
        }
    }

    private func didYouKnowSection(_ fact: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Did you know?")
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
            Text(fact)
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.inkMuted)
        }
    }

    private var findCareLink: some View {
        NavigationLink(value: CareDestination()) {
            HStack(spacing: DoggoSpacing.xs) {
                Text("Know a dog that needs help? Find nearby care")
                Image(systemName: "arrow.right")
            }
            .font(DoggoTextStyle.bodySemibold)
            .foregroundStyle(DoggoColor.marigold)
        }
        .padding(.top, DoggoSpacing.xs)
    }
}

/// Loading indicator for "Scout's having a sniff…" — three dots bouncing
/// with a staggered delay, same technique as AmbientBackgroundShapes. Not a
/// spinner, per the design brief. Internal (not private) so CareView's
/// live-search loading state can reuse it too.
struct BouncingDotsView: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DoggoColor.inkMuted)
                    .frame(width: 6, height: 6)
                    .offset(y: bounce ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                        value: bounce
                    )
            }
        }
        .onAppear { bounce = true }
    }
}
