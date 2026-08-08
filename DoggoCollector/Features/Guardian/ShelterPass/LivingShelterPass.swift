//
//  LivingShelterPass.swift
//  DoggoCollector
//
//  Life A — the Shelter Pass on screen: a warm sunlit light field
//  (ShelterPassLightField) with an opaque paper pass floating on it, Liquid
//  Glass chrome, Scout's paw seal, and the dog's photo.
//
//  Entrance is deliberately simple and bulletproof: the pass rises and fades
//  in once, then stays fully opaque and still. (An earlier, elaborate
//  multi-beat "ceremony" could fade the whole pass back out — that's gone.)
//

import SwiftUI

struct LivingShelterPass: View {
    let model: ShelterPassModel
    /// First-ever open → play the entrance + a soft haptic; re-open → appear
    /// instantly. Either way the pass ends fully visible and stable.
    let runFullCeremony: Bool
    var onClose: () -> Void = {}
    var onShare: () -> Void = {}
    var onPrint: () -> Void = {}
    /// Fired once, so the host can stamp `shelterPassIssuedAt`.
    var onIssued: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tilt = TiltProvider()
    /// The paper rises + fades in once, then holds forever. Separate from the
    /// per-field reveal so the pass itself can never fade back out.
    @State private var passVisible = false
    /// Monotonic 0…11 — each data group appears when it's reached. Only ever
    /// increases; it never resets, so nothing that appeared can disappear.
    @State private var revealStep = 0

    /// Total stamped groups (photo → seal).
    private static let revealSteps = 11

    private let haptics = ShelterPassHaptics()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShelterPassLightField(tilt: tilt)

            ScrollView {
                passCard
                    .padding(.horizontal, 26)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
        .task { await runReveal() }
    }

    /// The paper rises, then each data group stamps in one by one with a light
    /// haptic tick (a soft one on the seal). Everything only ever *appears* —
    /// no reset, no looping "breathe", no light-field dimming — so the pass
    /// can't fade away the way the old ceremony did.
    private func runReveal() async {
        guard revealStep == 0 else { return }

        // Re-opening an already-issued pass: show it whole, no stagger.
        if !runFullCeremony {
            passVisible = true
            revealStep = Self.revealSteps
            return
        }

        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.9)) {
            passVisible = true
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 140 : 300))

        for n in 1...Self.revealSteps {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.22) : .spring(response: 0.3, dampingFraction: 0.86)) {
                revealStep = n
            }
            haptics.play(n == Self.revealSteps ? .soft : .light)
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 95))
        }
        onIssued()
    }

    // MARK: - Chrome (Liquid Glass), inside the safe area

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DoggoColor.ink)
                    .regularGlassCircleChrome(size: 40)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, DoggoSpacing.sm)
        .padding(.bottom, DoggoSpacing.xs)
    }

    private var bottomBar: some View {
        HStack {
            // Print (left) — marigold-filled circle so the primary action reads.
            Button(action: onPrint) {
                Image(systemName: "printer.fill").font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(LinearGradient(colors: [Color(hex: 0xFFB63A), DoggoColor.marigold],
                                               startPoint: .top, endPoint: .bottom), in: Circle())
                    .shadow(color: DoggoColor.marigoldDark.opacity(0.5), radius: 12, y: 6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Print or save PDF")

            Spacer()

            // Share (right) — glass circle.
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DoggoColor.ink)
                    .regularGlassCircleChrome(size: 54)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, 24)
        .padding(.top, DoggoSpacing.sm)
        .padding(.bottom, DoggoSpacing.xs)
    }

    // MARK: - The paper pass

    private var passCard: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                photoIdentityRow
                stamp(6, statusRow)
                if model.hasClinic { stamp(7, clinicSection) }
                stamp(8, medsSection)
                stamp(9, timelineSection)
                stamp(10, recordsSection)
                if let note = model.handoverNote { stamp(10, handoverSection(note)) }
            }
            stamp(11, footer)
        }
        .background(
            LinearGradient(colors: [DoggoColor.passPaper1, DoggoColor.passPaper2],
                           startPoint: .top, endPoint: .bottom))
        .overlay(GuillocheOverlay(color: DoggoColor.passGrainInk.opacity(0.13)).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.6), lineWidth: 1))
        .shadow(color: Color(hex: 0x96641E).opacity(0.42), radius: 30, y: 24)
        // The paper rises + fades in once, then holds. (Individual data groups
        // stamp in on top of it via `revealStep`.)
        .scaleEffect(passVisible ? 1 : 0.97)
        .offset(y: passVisible ? 0 : 18)
        .opacity(passVisible ? 1 : 0)
    }

    /// Per-group stamp: fade + a small rise (opacity-only under Reduce Motion).
    /// Offsets are visual, so a not-yet-revealed group holds its layout slot and
    /// nothing jumps as the reveal runs.
    private func stamp<V: View>(_ n: Int, _ view: V) -> some View {
        view
            .opacity(revealStep >= n ? 1 : 0)
            .offset(y: (revealStep >= n || reduceMotion) ? 0 : 8)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STREET DOG CARE RECORD")
                        .font(DoggoFont.body(9, weight: .black)).tracking(2.3)
                        .foregroundStyle(DoggoColor.ink.opacity(0.72))
                    Text(model.name)
                        .font(DoggoFont.display(34, weight: .heavy))
                        .foregroundStyle(DoggoColor.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.serialDisplay)
                        .font(DoggoFont.display(22, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(DoggoColor.ink)
                    Text("ISSUED \(model.issuedDisplay)")
                        .font(DoggoFont.body(9.5, weight: .heavy)).tracking(1.1).monospacedDigit()
                        .foregroundStyle(DoggoColor.ink.opacity(0.66))
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 16)
            .background(
                LinearGradient(colors: [DoggoColor.passHeader1, DoggoColor.passHeader2, DoggoColor.passHeader3],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    // Static soft light band (no motion) — a fixed hint of sheen.
                    .overlay(
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.35),
                                    .init(color: .white.opacity(0.28), location: 0.5),
                                    .init(color: .clear, location: 0.65)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        .allowsHitTesting(false))
            )

            Rectangle().fill(LinearGradient(
                colors: [DoggoColor.passGrainInk.opacity(0), DoggoColor.passGrainInk.opacity(0.55), DoggoColor.passGrainInk.opacity(0)],
                startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
        }
    }

    // MARK: Photo + identity

    private var photoIdentityRow: some View {
        HStack(alignment: .top, spacing: 14) {
            stamp(1, photo)
            VStack(alignment: .leading, spacing: 0) {
                stamp(2, identityField("BREED", model.breed, est: model.breedEstimated))
                stamp(3, HStack(alignment: .top, spacing: 12) {
                    if let age = model.age { identityField("AGE", age, est: true) }
                    if let sex = model.sex { identityField("SEX", sex, est: false) }
                }
                .padding(.top, model.age == nil && model.sex == nil ? 0 : 11))
                stamp(4, identityField("TERRITORY", model.territory, est: false).padding(.top, 11))
                stamp(5, identityField("GUARDIAN", model.handle, est: false).padding(.top, 11))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)
    }

    private var photo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xFFF6E4))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DoggoColor.sealRing, lineWidth: 1.5))
                .shadow(color: Color(hex: 0x785014).opacity(0.4), radius: 12, y: 8)
                .padding(-5)
            Group {
                if let img = PhotoDecoder.image(from: model.photoData, size: .card, cacheKey: model.photoCacheKey) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    PolkaDotPlaceholder(seed: model.photoCacheKey.hashValue)
                }
            }
            .frame(width: 116, height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottom) {
                Text("PORTRAIT \u{00B7} OBS.")
                    .font(DoggoFont.body(8, weight: .black)).tracking(1.3)
                    .foregroundStyle(Color(hex: 0xFFEFD3))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(DoggoColor.ink, in: RoundedRectangle(cornerRadius: 6))
                    .offset(y: 8)
            }
        }
        .frame(width: 116, height: 146)
    }

    private func identityField(_ label: String, _ value: String, est: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(label).font(DoggoFont.body(9, weight: .black)).tracking(1.8)
                    .foregroundStyle(DoggoColor.inkMuted)
                provTag(est: est)
            }
            Text(value).font(DoggoFont.body(15, weight: .heavy))
                .foregroundStyle(DoggoColor.ink).lineLimit(2).minimumScaleFactor(0.8)
        }
    }

    // MARK: Status (sterilization + vaccination)

    private var statusRow: some View {
        HStack(spacing: 10) {
            statusCell(label: "STERILIZATION", value: model.sterLabel, done: model.sterDone, known: model.sterKnown)
            statusCell(label: "VACCINATION", value: model.vaxLabel, done: model.vaxDone, known: true)
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private func statusCell(label: String, value: String, done: Bool, known: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(done ? DoggoColor.statusDoneAccent : (known ? Color.clear : DoggoColor.inkMuted.opacity(0.25)))
                Image(systemName: done ? "checkmark" : (known ? "circle" : "questionmark"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(done ? .white : DoggoColor.inkMuted)
            }
            .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(DoggoFont.body(8.5, weight: .black)).tracking(1.6)
                    .foregroundStyle(DoggoColor.inkMuted)
                Text(value).font(DoggoFont.body(13.5, weight: .heavy))
                    .foregroundStyle(DoggoColor.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(done ? DoggoColor.statusDoneBg : DoggoColor.statusUnknownBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(done ? DoggoColor.statusDoneBorder : DoggoColor.statusUnknownBorder, lineWidth: 1))
    }

    // MARK: Clinic

    private var clinicSection: some View {
        // A pass is a document, not a control surface — so the clinic shows its
        // contact details as text (name / address · phone) for the shelter to
        // read and dial, with no tappable Call button. (One-tap calling lives
        // on the dog's gallery screen, where you're actually caring day to day.)
        VStack(alignment: .leading, spacing: 7) {
            sectionEyebrow("ASSIGNED CLINIC")
            VStack(alignment: .leading, spacing: 2) {
                Text(model.clinicName ?? "").font(DoggoFont.body(14, weight: .heavy)).foregroundStyle(DoggoColor.ink)
                let detail = [model.clinicAddr, model.clinicPhone].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
                if !detail.isEmpty {
                    Text(detail).font(DoggoFont.body(11.5)).foregroundStyle(DoggoColor.inkMuted).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(DoggoColor.passPaper1, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DoggoColor.passHairline, lineWidth: 1))
        }
        .padding(.horizontal, 20).padding(.top, 14)
    }

    // MARK: Medications

    private var medsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionEyebrow("ACTIVE MEDICATION")
            if model.medications.isEmpty {
                dashedNote("None on the books — nothing prescribed right now.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.medications.enumerated()), id: \.element.id) { i, m in
                        HStack(spacing: 10) {
                            Text("Rx").font(DoggoFont.body(12, weight: .black)).foregroundStyle(DoggoColor.logMedFg)
                                .frame(width: 26, height: 26)
                                .background(DoggoColor.logMedBg, in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.name).font(DoggoFont.body(13.5, weight: .heavy)).foregroundStyle(DoggoColor.ink)
                                Text("\(m.dose) \u{00B7} \(m.freq)").font(DoggoFont.body(11.5)).foregroundStyle(DoggoColor.inkMuted)
                            }
                            Spacer(minLength: 0)
                            Text(m.since).font(DoggoFont.body(10.5, weight: .heavy)).monospacedDigit().foregroundStyle(DoggoColor.inkMuted)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        if i < model.medications.count - 1 {
                            Rectangle().fill(DoggoColor.passHairline.opacity(0.7)).frame(height: 1)
                        }
                    }
                }
                .background(DoggoColor.passMedBg, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xE2D8C6), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.top, 14)
    }

    // MARK: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionEyebrow("LOGGED CARE HISTORY")
                provTag(est: false)
                Spacer()
                if model.logCount > 0 {
                    Text("\(model.logCount)").font(DoggoFont.body(10, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Color(hex: 0xB0A088))
                }
            }
            if model.careLog.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("The story starts here").font(DoggoFont.display(15, weight: .heavy)).foregroundStyle(DoggoColor.ink)
                    Text("Every bowl, dose and check you log lands on this page — and travels with them.")
                        .font(DoggoFont.body(12)).foregroundStyle(DoggoColor.inkMuted)
                }
                .padding(.horizontal, 14).padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DoggoColor.passMedBg, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color(hex: 0xE2D8C6)))
            } else {
                VStack(spacing: 0) {
                    ForEach(model.careLog.prefix(ShelterPassModel.screenLogLimit)) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: row.glyph).font(.system(size: 13)).foregroundStyle(DoggoColor.inkMuted).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.title).font(DoggoFont.body(13, weight: .heavy)).foregroundStyle(DoggoColor.ink)
                                if !row.sub.isEmpty {
                                    Text(row.sub).font(DoggoFont.body(11.5)).foregroundStyle(DoggoColor.inkMuted).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(row.whenShort).font(DoggoFont.body(10.5, weight: .heavy)).monospacedDigit().foregroundStyle(Color(hex: 0xB0A088))
                        }
                        .padding(.vertical, 7)
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(DoggoColor.passHairline).frame(width: 1).padding(.vertical, 12).padding(.leading, 9).opacity(0.6)
                }
                if let more = model.moreLabel {
                    Text(more).font(DoggoFont.body(11.5, weight: .heavy)).monospacedDigit().foregroundStyle(DoggoColor.issuedInk)
                        .padding(.top, 9)
                        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xEAE2D3)).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    // MARK: Records

    private var recordsSection: some View {
        HStack(spacing: 10) {
            Text("\u{2630}").font(.system(size: 12, weight: .black)).foregroundStyle(DoggoColor.issuedInk)
                .frame(width: 24, height: 24)
                .background(DoggoColor.provEstBg, in: RoundedRectangle(cornerRadius: 7))
            (Text("Medical records on file: \(model.recordCount)").font(DoggoFont.body(12.5, weight: .heavy)).foregroundColor(DoggoColor.ink)
             + Text(" — ask the guardian and they'll send them over.").font(DoggoFont.body(12.5)).foregroundColor(DoggoColor.inkMuted))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(DoggoColor.passMedBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DoggoColor.passHairline, lineWidth: 1))
        .padding(.horizontal, 20).padding(.top, 14)
    }

    private func handoverSection(_ note: String) -> some View {
        Text(note).font(DoggoFont.body(12.5)).foregroundStyle(DoggoColor.ink).lineSpacing(2)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DoggoColor.passHandoverBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DoggoColor.passHandoverBorder, lineWidth: 1))
            .padding(.horizontal, 20).padding(.top, 9)
    }

    // MARK: Footer (seal band)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                PawSeal(size: 82)
                VStack(alignment: .leading, spacing: 0) {
                    Text("ISSUED").font(DoggoFont.display(15, weight: .heavy)).tracking(2.4)
                        .foregroundStyle(DoggoColor.issuedInk)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DoggoColor.issuedInk.opacity(0.8), lineWidth: 2))
                        .rotationEffect(.degrees(-3.5))
                        .padding(.bottom, 7)
                    (Text("Self-issued by guardian ").foregroundColor(DoggoColor.inkMuted)
                     + Text(model.handle).foregroundColor(DoggoColor.ink).bold()
                     + Text(" via ").foregroundColor(DoggoColor.inkMuted)
                     + Text("DoggoCollector").foregroundColor(DoggoColor.ink).bold()
                     + Text(" \u{00B7} \(model.issuedDisplay) \u{00B7} \(model.serialDisplay). A caretaker's record. Not a government or veterinary document.")
                        .foregroundColor(DoggoColor.inkMuted))
                        .font(DoggoFont.body(11.5)).lineSpacing(3)
                }
            }
            Rectangle().fill(Color(hex: 0xE2D8C6)).frame(height: 1).padding(.top, 12)
            (Text("EST.").foregroundColor(DoggoColor.issuedInk).bold()
             + Text(" our best guess from a photo — not verified.   ").foregroundColor(DoggoColor.inkMuted)
             + Text("OBS.").foregroundColor(DoggoColor.statusDoneAccent).bold()
             + Text(" first-hand, logged by the guardian.").foregroundColor(DoggoColor.inkMuted))
                .font(DoggoFont.body(10.5)).lineSpacing(3).padding(.top, 10)
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [DoggoColor.passFooter1, DoggoColor.passFooter2], startPoint: .top, endPoint: .bottom)
                .overlay(GuillocheLines(color: DoggoColor.passGrainInk.opacity(0.09)))
        )
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xEAE2D3)).frame(height: 1) }
    }

    // MARK: Small shared bits

    private func sectionEyebrow(_ t: String) -> some View {
        Text(t).font(DoggoFont.body(9, weight: .black)).tracking(2).foregroundStyle(DoggoColor.inkMuted)
    }
    private func provTag(est: Bool) -> some View {
        Text(est ? "EST." : "OBS.")
            .font(DoggoFont.body(8, weight: .semibold)).tracking(0.8)
            .foregroundStyle(est ? DoggoColor.provEstFg : DoggoColor.provObsFg)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(est ? DoggoColor.provEstBg : DoggoColor.provObsBg, in: RoundedRectangle(cornerRadius: 5))
    }
    private func dashedNote(_ t: String) -> some View {
        Text(t).font(DoggoFont.body(12.5)).foregroundStyle(DoggoColor.inkMuted)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DoggoColor.passMedBg, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color(hex: 0xE2D8C6)))
    }
}

// MARK: - Guilloché (fine-line motifs, drawn once)

/// Faint concentric arcs across the whole document (the screen guilloché).
struct GuillocheOverlay: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width * 0.5, y: -size.height * 0.3)
            var r: CGFloat = 5
            let maxR = hypot(size.width, size.height * 1.3)
            while r < maxR {
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 0.5)
                r += 5
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

/// A fine 74° rule band for the footer.
struct GuillocheLines: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 6
            let angle = CGFloat(74) * .pi / 180
            let dx = cos(angle), dy = sin(angle)
            var d = -size.height
            let maxD = size.width + size.height
            while d < maxD {
                var path = Path()
                path.move(to: CGPoint(x: d, y: 0))
                path.addLine(to: CGPoint(x: d + dx * size.height / max(dy, 0.01), y: size.height))
                ctx.stroke(path, with: .color(color), lineWidth: 1)
                d += spacing / max(dy, 0.3)
            }
        }
        .allowsHitTesting(false)
    }
}
