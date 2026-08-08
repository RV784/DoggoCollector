//
//  ShelterPassPrintDocument.swift
//  DoggoCollector
//
//  Life B — the Artifact. What actually leaves the phone: one 612×900pt page,
//  flat ink-on-white, grayscale-safe, rasterized to PDF/image by CardRenderer.
//  The same object as the Living Pass, at rest and flattened for the world —
//  marigold band → 2px ink rule, emboss → hairline, status colour → ink boxes,
//  timeline → a 3-column dated ledger, foil seal → a solid ink paw. Faithful
//  to Shelter Pass.dc.html · "03 · LIFE B".
//

import SwiftUI

struct ShelterPassPrintDocument: View {
    let model: ShelterPassModel

    private var ledgerRows: [ShelterPassModel.LogRow] {
        Array(model.careLog.prefix(ShelterPassModel.printLedgerLimit))
    }
    private var collapsed: [ShelterPassModel.LogRow] {
        Array(model.careLog.dropFirst(ShelterPassModel.printLedgerLimit))
    }
    private var entriesRangeLabel: String {
        guard let latest = model.careLog.first?.date, let earliest = model.careLog.last?.date else {
            return "\(model.logCount) ENTRIES"
        }
        let f: (Date) -> String = { $0.formatted(.dateTime.day().month(.abbreviated)).uppercased() }
        return "\(model.logCount) ENTRIES \u{00B7} \(f(earliest)) \u{2013} \(f(latest))"
    }

    var body: some View {
        ZStack {
            Color.white
            // Double border + arc bands.
            Rectangle().stroke(DoggoColor.printGuilloche, lineWidth: 1).padding(14)
            Rectangle().stroke(DoggoColor.printHair, lineWidth: 1).padding(19)
            VStack {
                PrintArcBand(flip: false).frame(height: 26).padding(.horizontal, 19).padding(.top, 19)
                Spacer()
                PrintArcBand(flip: true).frame(height: 26).padding(.horizontal, 19).padding(.bottom, 19)
            }

            ZStack(alignment: .top) {
                content.padding(.horizontal, 46).padding(.top, 34)
                VStack { Spacer(); footer.padding(.horizontal, 46).padding(.bottom, 44) }
            }
        }
        .frame(width: 612, height: 900)
        .foregroundStyle(DoggoColor.printInk)
        .font(.system(size: 13))
        .environment(\.colorScheme, .light)
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            photoAndIdentity
            statusBoxes
            clinicAndMed
            ledger
        }
    }

    private var headerRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("STREET DOG CARE RECORD").font(.system(size: 10, weight: .black)).tracking(3.2)
                    .foregroundStyle(DoggoColor.printGrey)
                Text(model.name).font(DoggoFont.display(40, weight: .heavy))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.serialDisplay).font(DoggoFont.display(30, weight: .heavy)).monospacedDigit()
                Text("ISSUED \(model.issuedDisplay)").font(.system(size: 10, weight: .black)).tracking(1.4).monospacedDigit()
                    .foregroundStyle(DoggoColor.printGrey)
            }
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(DoggoColor.printInk).frame(height: 2) }
    }

    private var photoAndIdentity: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Group {
                    if let img = PhotoDecoder.image(from: model.photoData, size: .document, cacheKey: model.photoCacheKey) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(hex: 0xF1E7D6))
                    }
                }
                .frame(width: 138, height: 138).clipped()
                .padding(5).background(Color.white)
                .overlay(Rectangle().stroke(DoggoColor.printInk, lineWidth: 1.5))
                Text("PORTRAIT \u{00B7} OBS.").font(.system(size: 9, weight: .black)).tracking(1.6)
                    .foregroundStyle(DoggoColor.printGrey).frame(width: 150, alignment: .leading)
            }
            identityGrid
        }
    }

    private var identityGrid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                identityCell("BREED", model.breed, est: model.breedEstimated, right: true)
                identityCell("APPROX. AGE", model.age ?? "—", est: true, right: false)
            }
            GridRow {
                identityCell("SEX", model.sex ?? "—", est: false, right: true)
                identityCell("GUARDIAN", model.handle, est: false, right: false)
            }
            GridRow {
                identityCell("TERRITORY", model.territory, est: false, right: false)
                    .gridCellColumns(2)
            }
        }
        .overlay(Rectangle().stroke(DoggoColor.printInk, lineWidth: 1))
    }

    private func identityCell(_ label: String, _ value: String, est: Bool, right: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 9, weight: .black)).tracking(1.8).foregroundStyle(DoggoColor.printGrey)
                printTag(est: est)
            }
            Text(value).font(.system(size: 15, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 13).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) { if right { Rectangle().fill(DoggoColor.printHair).frame(width: 1) } }
        .overlay(alignment: .bottom) { Rectangle().fill(DoggoColor.printHair).frame(height: 1) }
    }

    private var statusBoxes: some View {
        HStack(spacing: 10) {
            statusBox("STERILIZATION", model.sterLabel, ticked: model.sterDone)
            statusBox("VACCINATION", model.vaxLabel, ticked: model.vaxDone)
        }
    }
    private func statusBox(_ label: String, _ value: String, ticked: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(DoggoColor.printInk, lineWidth: 1.5)
                if ticked { Image(systemName: "checkmark").font(.system(size: 12, weight: .black)) }
            }.frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 9, weight: .black)).tracking(1.8).foregroundStyle(DoggoColor.printGrey)
                Text(value).font(.system(size: 15, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(DoggoColor.printInk, lineWidth: 1.5))
    }

    private var clinicAndMed: some View {
        HStack(spacing: 10) {
            infoBox("ASSIGNED CLINIC",
                    title: model.clinicName ?? "Not assigned",
                    detail: [model.clinicAddr, model.clinicPhone].compactMap { $0 }.joined(separator: " \u{00B7} "))
            infoBox("ACTIVE MEDICATION",
                    title: model.medications.first?.name ?? "None",
                    detail: model.medications.first.map { "\($0.dose) \u{00B7} \($0.freq) \u{00B7} \($0.since)" } ?? "Nothing prescribed")
        }
    }
    private func infoBox(_ label: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .black)).tracking(1.8).foregroundStyle(DoggoColor.printGrey)
            Text(title).font(.system(size: 14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.system(size: 12)).foregroundStyle(DoggoColor.printGrey).lineLimit(2)
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(DoggoColor.printHair, lineWidth: 1))
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("LOGGED CARE HISTORY").font(.system(size: 9.5, weight: .black)).tracking(2.4)
                printTag(est: false)
                Spacer()
                Text(entriesRangeLabel).font(.system(size: 10, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(DoggoColor.printGrey)
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) { Rectangle().fill(DoggoColor.printInk).frame(height: 1.5) }

            if model.careLog.isEmpty {
                Text("No care logged yet — the story starts here.")
                    .font(.system(size: 12.5)).foregroundStyle(DoggoColor.printGrey).padding(.top, 6)
            } else {
                ForEach(ledgerRows) { r in
                    HStack(spacing: 0) {
                        Text(r.date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(DoggoColor.printGrey).frame(width: 76, alignment: .leading)
                        Text(r.kind).font(.system(size: 11, weight: .black)).tracking(1.1).frame(width: 96, alignment: .leading)
                        Text(r.sub.isEmpty ? "—" : r.sub).font(.system(size: 12.5)).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xEFE9DD)).frame(height: 1) }
                }
                if !collapsed.isEmpty { collapsedSummary }
            }
            Text("Medical records on file: \(model.recordCount) — sterilization certificate, vaccination card, prescriptions. Sent on request.")
                .font(.system(size: 11)).foregroundStyle(DoggoColor.printGrey).padding(.top, 6).lineLimit(2)
        }
    }

    private var collapsedSummary: some View {
        let counts = Dictionary(grouping: collapsed, by: { $0.kind }).mapValues { $0.count }
        let parts = counts.sorted { $0.value > $1.value }.map { "\($0.value) \($0.key.lowercased())" }
        let range: String = {
            guard let a = collapsed.last?.date, let b = collapsed.first?.date else { return "" }
            let f: (Date) -> String = { $0.formatted(.dateTime.day().month(.abbreviated)) }
            return "(\(f(a)) – \(f(b))): "
        }()
        return Text("\(range)\(parts.joined(separator: ", ")). ")
            .font(.system(size: 11)).foregroundStyle(DoggoColor.printGrey)
        + Text("+ \(collapsed.count) earlier entries").font(.system(size: 11, weight: .heavy)).foregroundColor(DoggoColor.printInk)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrintGuillocheRule().frame(height: 10).opacity(0.5).padding(.bottom, 9)
            HStack(alignment: .top, spacing: 14) {
                PawSeal.Flat(size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ISSUED").font(DoggoFont.display(14, weight: .heavy)).tracking(2.6)
                        .padding(.horizontal, 9).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(DoggoColor.printInk, lineWidth: 1.5))
                        .rotationEffect(.degrees(-2.5))
                    (Text("Self-issued by guardian ").foregroundColor(DoggoColor.printInk)
                     + Text(model.handle).bold()
                     + Text(" through ") + Text("DoggoCollector").bold()
                     + Text(" \u{00B7} \(model.issuedDisplay) \u{00B7} \(model.serialDisplay). This is a caretaker's own record of the care they have given. It is ")
                     + Text("not").bold()
                     + Text(" a government or veterinary document."))
                        .font(.system(size: 10.5)).foregroundColor(DoggoColor.printInk).lineSpacing(1.5)
                    (Text("EST.").bold() + Text(" = estimated from a photograph, unverified.   ")
                     + Text("OBS.").bold() + Text(" = observed and logged first-hand by the guardian."))
                        .font(.system(size: 10)).foregroundColor(DoggoColor.printGrey).lineSpacing(1)
                }
            }
            .padding(.top, 9)
            .overlay(alignment: .top) { Rectangle().fill(DoggoColor.printInk).frame(height: 2) }
        }
    }

    private func printTag(est: Bool) -> some View {
        Text(est ? "EST." : "OBS.")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(est ? DoggoColor.printEstFg : DoggoColor.printObsFg)
            .padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(est ? DoggoColor.printGuilloche : DoggoColor.printObsFg, lineWidth: 1))
    }
}

// MARK: - Print guilloché

private struct PrintArcBand: View {
    var flip: Bool
    var body: some View {
        Canvas { ctx, size in
            let cy: CGFloat = flip ? -size.height * 0.4 : size.height * 1.4
            var r: CGFloat = 4
            while r < size.width {
                let rect = CGRect(x: size.width / 2 - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: rect), with: .color(DoggoColor.printGuilloche.opacity(0.5)), lineWidth: 0.6)
                r += 4.5
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }
}

private struct PrintGuillocheRule: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 5
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height / tan(74 * .pi / 180), y: 0))
                ctx.stroke(p, with: .color(DoggoColor.printGuilloche.opacity(0.55)), lineWidth: 0.7)
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
