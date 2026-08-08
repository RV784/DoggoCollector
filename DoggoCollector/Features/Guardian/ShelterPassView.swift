//
//  ShelterPassView.swift
//  DoggoCollector
//
//  Host for the redesigned Shelter Pass (Shelter Pass.dc.html). Builds the
//  flattened ShelterPassModel (including an optional AI age bracket, briefly
//  raced so the pass isn't held up), presents the on-screen LivingShelterPass
//  with the once-per-issuance ceremony gate, and renders the flat
//  ShelterPassPrintDocument to PDF for Print / Share.
//
//  Split of screen (Life A, LivingShelterPass) vs artifact (Life B,
//  ShelterPassPrintDocument) is deliberate — the two are different views now,
//  not one shared body. See shelter_pass_redesign_implementation.md.
//

import SwiftUI
import SwiftData
import UIKit

struct ShelterPassView: View {
    let dog: CaughtDog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GameCenterAuthProvider.self) private var authProvider

    @State private var model: ShelterPassModel?
    @State private var pdfURL: URL?
    @State private var showActivitySheet = false

    private let insightProvider: DogInsightProviding = FoundationModelsInsightProvider()

    var body: some View {
        ZStack {
            // The ceremony ignites from dark, so a black hold while the model
            // resolves transitions seamlessly into the light field coming up.
            Color.black.ignoresSafeArea()

            if let model {
                LivingShelterPass(
                    model: model,
                    // Play the staggered reveal every time the pass is opened,
                    // not just the first — the reveal is the point of the screen.
                    runFullCeremony: true,
                    onClose: { dismiss() },
                    onShare: { sharePass() },
                    onPrint: { printPass() },
                    onIssued: {
                        guard dog.shelterPassIssuedAt == nil else { return }
                        dog.shelterPassIssuedAt = .now
                        try? modelContext.save()
                    }
                )
            }
        }
        .task { await prepare() }
        .sheet(isPresented: $showActivitySheet) {
            if let pdfURL { ActivityView(activityItems: [pdfURL]) }
        }
    }

    // MARK: - Prepare

    private func prepare() async {
        guard model == nil else { return }
        let username = authProvider.currentUsername ?? "scout"
        // Show the pass immediately (age nil) so the mint isn't held up; the AI
        // age bracket fills in when it resolves. In the common instant-fallback
        // case it's there before the ceremony even reaches the AGE beat (~1.1s).
        model = ShelterPassModel.make(dog: dog, username: username, age: nil)
        let insight = await insightProvider.insight(for: dog)
        model?.age = "\u{2248} \(insight.ageBracket.rawValue)"
    }

    // MARK: - Export

    private func renderPassPDF() -> URL? {
        guard let model else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelterPass-\(dog.name).pdf")
        let ok = CardRenderer.renderPDF(
            ShelterPassPrintDocument(model: model),
            size: CGSize(width: 612, height: 900),
            to: url)
        return ok ? url : nil
    }

    private func printPass() {
        guard let url = renderPassPDF() else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "\(dog.name) Shelter Pass"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = url
        controller.present(animated: true, completionHandler: nil)
    }

    private func sharePass() {
        guard let url = renderPassPDF() else { return }
        pdfURL = url
        showActivitySheet = true
    }
}
