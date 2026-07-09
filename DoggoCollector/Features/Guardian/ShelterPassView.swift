//
//  ShelterPassView.swift
//  DoggoCollector
//
//  B4 — the Shelter Pass. Presented full-screen from the Dossier's export
//  button. White paper look, high contrast — deliberately not the cream app
//  chrome, since this reads as a document, not a card.
//
//  `ShelterPassContent` is split out so it can be rendered to PDF
//  independently of the screen chrome around it (see CardRenderer.renderPDF).
//

import SwiftUI

struct ShelterPassView: View {
    let dog: CaughtDog

    @Environment(\.dismiss) private var dismiss
    @Environment(UsernameAuthProvider.self) private var authProvider
    @State private var pdfURL: URL?
    @State private var showActivitySheet = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                ShelterPassContent(dog: dog, username: authProvider.currentUsername ?? "scout")
            }
            bottomActions
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showActivitySheet) {
            if let pdfURL {
                ActivityView(activityItems: [pdfURL])
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xF1EBE0), in: Circle())
            }
        }
        .padding(DoggoSpacing.lg)
    }

    private var bottomActions: some View {
        VStack(spacing: DoggoSpacing.md) {
            PillButton(title: "Print / Save PDF", systemImage: "printer.fill", action: printPass)
            PillButton(title: "Share", systemImage: "square.and.arrow.up", style: .secondary, action: sharePass)
        }
        .padding(DoggoSpacing.lg)
        .background(Color.white)
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

    private func renderPassPDF() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ShelterPass-\(dog.name).pdf")
        let content = ShelterPassContent(dog: dog, username: authProvider.currentUsername ?? "scout")
        return CardRenderer.renderPDF(content, size: CGSize(width: 612, height: 900), to: url) ? url : nil
    }
}

/// The printable content itself — no screen chrome, so it can be rasterized
/// straight to a PDF page as well as shown on screen.
struct ShelterPassContent: View {
    let dog: CaughtDog
    let username: String

    private var serialText: String { "#" + String(format: "%03d", dog.serialNumber) }
    private var hairline: Color { Color(hex: 0xDDD5C7) }

    var body: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
            headerBand
            VStack(alignment: .leading, spacing: DoggoSpacing.lg) {
                StatusBadge(status: dog.sterilization)
                identityGrid
                careHistory
                legend
            }
            .padding(.horizontal, DoggoSpacing.lg)
            .padding(.bottom, DoggoSpacing.lg)
        }
        .background(Color.white)
    }

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
            Text(dog.name)
                .font(DoggoTextStyle.displayMedium)
                .foregroundStyle(.white)
            Text("\(serialText) \u{00B7} STREET DOG CARE RECORD")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(.white.opacity(0.85))
            Text("Issued \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                .font(DoggoTextStyle.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(DoggoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoggoColor.ink)
    }

    private var identityGrid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                identityCell(label: "BREED", value: dog.breedLabel, tag: .estimated)
                identityCell(label: "AGE", value: "See card", tag: nil)
            }
            GridRow {
                identityCell(label: "LOCATION", value: dog.locationLabel, tag: .observed)
                identityCell(label: "GUARDIAN", value: "@\(username)", tag: .observed)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hairline, lineWidth: 1))
    }

    private func identityCell(label: String, value: String, tag: StatusBadge.ProvenanceKind?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: DoggoSpacing.xs) {
                Text(label)
                    .font(DoggoTextStyle.eyebrow)
                    .foregroundStyle(DoggoColor.inkMuted)
                if let tag {
                    StatusBadge.ProvenanceTag(kind: tag)
                }
            }
            Text(value)
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
        }
        .padding(DoggoSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(hairline, lineWidth: 0.5))
    }

    private var careHistory: some View {
        VStack(alignment: .leading, spacing: DoggoSpacing.sm) {
            Text("LOGGED CARE HISTORY")
                .font(DoggoTextStyle.eyebrow)
                .foregroundStyle(DoggoColor.inkMuted)

            if dog.sortedCareEntries.isEmpty {
                Text("No care logged yet")
                    .font(DoggoTextStyle.bodyRegular)
                    .foregroundStyle(DoggoColor.inkMuted)
                    .padding(.vertical, DoggoSpacing.xs)
            } else {
                ForEach(dog.sortedCareEntries) { entry in
                    careRow(entry)
                }
            }
        }
    }

    private func careRow(_ entry: CareEntry) -> some View {
        HStack(alignment: .top, spacing: DoggoSpacing.sm) {
            Text(entry.type.title)
                .font(DoggoTextStyle.bodySemibold)
                .foregroundStyle(DoggoColor.ink)
            if !entry.note.isEmpty {
                Text("\u{2014} \(entry.note)")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.inkMuted)
            }
            Spacer()
            StatusBadge.ProvenanceTag(kind: .observed)
            Text(entry.timestamp.formatted(date: .abbreviated, time: .omitted))
                .font(DoggoTextStyle.caption)
                .foregroundStyle(DoggoColor.inkMuted)
        }
        .padding(.vertical, DoggoSpacing.xs)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(hairline), alignment: .bottom)
    }

    private var legend: some View {
        Text("Fields tagged **EST.** are AI photo-based guesses, not verified facts. Fields tagged **OBS.** are logged by the guardian.")
            .font(DoggoTextStyle.caption)
            .foregroundStyle(DoggoColor.inkMuted)
    }
}
