//
//  PosterCeremonyView.swift
//  DoggoCollector
//
//  The 4.5-second assembly — the loading state for the trait pass, made worth
//  watching. Every photo scatters in, orbits, collapses into a deck, the dog
//  lifts out, the colour floods up, and the poster builds itself band by band,
//  landing exactly where PosterView shows it. Timings/easings/haptics are the
//  design's own (~/Documents/poster_maker_design_extract.md):
//
//    swarm flyOrbit 2900ms · converge flash @2050 · heroLift @2240 ·
//    washUp @2880 · polaroid peel @3120/3230 · kicker slam @3520 ·
//    name slam @3640 (the climax haptic) · chips pop @3860/3940/4020 ·
//    block @4060 · bar @4180 · signature @4320 · progress 4500 · done @4750.
//
//  Reliability first (standing user feedback): the whole thing is driven by a
//  single monotonic `.task` timeline flipping one-way flags — no repeatForever,
//  nothing that can fade back out. The real PosterView cross-fades in at the
//  end, so the hand-off to the editor is a no-op.
//

import SwiftUI

struct PosterCeremonyView: View {
    struct SwarmTile: Identifiable { let id: UUID; let image: UIImage? }

    let model: PosterRenderModel
    /// The dog's photos, flying in — carried with their ids so each tile can
    /// matched-geometry from its exact pre-flight grid cell into the orbit.
    let swarmTiles: [SwarmTile]
    /// Shared with PosterPreflightView's grid so the flight is one continuous
    /// element, not a cross-fade.
    var tileNS: Namespace.ID
    var reduceMotion: Bool
    var onSkip: () -> Void
    var onFinished: () -> Void

    // Swarm: the ring the grid photos fly into, then rotate and collapse.
    @State private var swarmR: CGFloat = 150      // ring radius; → 0 to converge
    @State private var orbitAngle: Double = 0     // ring rotation (the orbit)
    @State private var swarmFade = false          // fades as the dog lifts out
    // Monotonic entrance flags — set once, never reset.
    @State private var flashIn = false
    @State private var heroIn = false
    @State private var washIn = false
    @State private var peelL = false
    @State private var peelR = false
    @State private var kickerIn = false
    @State private var nameIn = false
    @State private var chip = [false, false, false]
    @State private var blockIn = false
    @State private var barIn = false
    @State private var sigIn = false
    @State private var realPosterIn = false
    @State private var bgGround = false
    @State private var progress: CGFloat = 0
    @State private var didFinish = false

    // Haptic triggers.
    @State private var hLight = false
    @State private var hRigid = false
    @State private var hSoft = false
    @State private var hHeavy = false
    @State private var hSuccess = false

    private var a: PosterAccent { model.accent }
    private let W = PosterView.width
    private let H = PosterView.height
    private let centerY: CGFloat = 0.44 * PosterView.height

    var body: some View {
        GeometryReader { geo in
            // Fit width, anchored to the TOP — the exact same frame the editor
            // uses, so the card is at its final full-screen position from the
            // first frame and never moves when the ceremony hands off.
            let scale = geo.size.width / W
            ZStack(alignment: .top) {
                (bgGround ? (a.grounds.last ?? DoggoColor.cream) : Color(hex: 0x17120E))
                    .ignoresSafeArea()

                canvas
                    .frame(width: W, height: H)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: geo.size.width, height: H * scale, alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                // Skip (screen-level, crisp) — cross-fades to the finished poster.
                VStack {
                    HStack {
                        Spacer()
                        Button(action: skip) {
                            Text("Skip")
                                .font(PosterFont.nunito(13, weight: .extraBold))
                                .foregroundStyle(PosterPurpose.cream)
                                .padding(.horizontal, 15).padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                        }
                        .opacity(realPosterIn ? 0 : 1)
                    }
                    .padding(.horizontal, 18).padding(.top, 8)
                    Spacer()
                }

                // Progress bar pinned to the bottom.
                VStack {
                    Spacer()
                    GeometryReader { g in
                        Rectangle().fill(PosterPurpose.cream.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Rectangle().fill(DoggoColor.marigold)
                                    .frame(width: g.size.width * progress)
                            }
                    }
                    .frame(height: 3)
                    .opacity(realPosterIn ? 0 : 1)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hLight)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: hRigid)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: hSoft)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: hHeavy)
        .sensoryFeedback(.success, trigger: hSuccess)
        .task { await run() }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            // Assembly bands (simplified — the real PosterView cross-fades over
            // them at the end, so this is the build-up, not the final artifact).
            washGround
            heroLayer
            if model.layout != .photoLed { polaroidLayer }
            kickerLayer
            nameLayer
            chipLayer
            blockLayer
            barLayer
            sigLayer

            // Swarm rides above the assembly until it fades out on its own.
            swarmLayer

            // Converge flash — the single soft pulse as the deck lands.
            flashLayer

            // The finished poster, cross-faded in at ~4.4s.
            PosterView(model: model)
                .opacity(realPosterIn ? 1 : 0)
        }
        .frame(width: W, height: H)
        .clipped()
    }

    // MARK: - Swarm

    private var swarmLayer: some View {
        let n = max(1, swarmTiles.count)
        return ZStack {
            ForEach(Array(swarmTiles.enumerated()), id: \.element.id) { i, tile in
                let base = (Double(i) / Double(n)) * 2 * .pi
                // Slight per-tile radius jitter so the ring reads organic, not
                // mechanical.
                let rx = swarmR * (1 + Double((i * 13) % 7 - 3) / 55)
                let ry = swarmR * 1.05 * (1 + Double((i * 17) % 7 - 3) / 55)
                let ang = base + orbitAngle
                swarmTile(tile)
                    .position(x: W / 2 + cos(ang) * rx, y: centerY + sin(ang) * ry)
            }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func swarmTile(_ tile: SwarmTile) -> some View {
        // Straightens as the deck converges (radius shrinks).
        let tilt = swarmR < 30 ? 0 : Double((abs(tile.id.hashValue) % 15) - 7)
        let body = swarmTileBody(tile)
            .rotationEffect(.degrees(tilt))
            .opacity(swarmFade ? 0 : 1)
        if reduceMotion {
            body
        } else {
            // The one continuous element: each tile flies from its exact
            // pre-flight grid cell (the matched source) into this ring position.
            body.matchedGeometryEffect(id: "swarmtile-\(tile.id)", in: tileNS, isSource: false)
        }
    }

    private func swarmTileBody(_ tile: SwarmTile) -> some View {
        Group {
            if let img = tile.image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Rectangle().fill(LinearGradient(colors: [a.tint, a.accent.opacity(0.7)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: 92, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PosterPurpose.cream.opacity(0.92), lineWidth: 3))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 11)
    }

    @ViewBuilder
    private var flashLayer: some View {
        if flashIn && !reduceMotion {
            KeyframeAnimator(initialValue: FlashFrame(scale: 0.3, opacity: 0), trigger: flashIn) { f in
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFD696).opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .scaleEffect(f.scale)
                    .opacity(f.opacity)
            } keyframes: { _ in
                KeyframeTrack(\FlashFrame.opacity) {
                    LinearKeyframe(0.85, duration: 0.248)
                    LinearKeyframe(0, duration: 0.372)
                }
                KeyframeTrack(\FlashFrame.scale) {
                    CubicKeyframe(2.4, duration: 0.62)
                }
            }
            .position(x: W / 2, y: centerY)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Assembly bands

    private var washGround: some View {
        Rectangle().fill(a.groundGradient)
            .frame(width: W, height: H)
            .scaleEffect(x: 1, y: washIn ? 1 : (reduceMotion ? 1 : 0.001), anchor: .bottom)
            .opacity(washIn ? 1 : 0)
    }

    @ViewBuilder
    private var heroLayer: some View {
        let hm: (top: CGFloat, height: CGFloat) = {
            switch model.purpose {
            case .missing: return (190, 322)
            case .found: return (216, 296)
            case .adopt: return (292, 220)
            }
        }()
        heroBody
            .frame(width: 404, height: hm.height)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: a.deep.opacity(0.3), radius: 14, y: 15)
            .modifier(HeroLift(shown: heroIn, reduce: reduceMotion))
            .place((W - 404) / 2, hm.top, w: 404)
    }

    @ViewBuilder
    private var heroBody: some View {
        if let hero = model.hero {
            Image(uiImage: hero).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        } else {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.white.opacity(0.55), a.tint.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "pawprint.fill").font(.system(size: 60)).foregroundStyle(a.accent.opacity(0.25)))
        }
    }

    private var polaroidLayer: some View {
        let top: CGFloat = 302
        let pw: CGFloat = 150
        return ZStack(alignment: .topLeading) {
            polaroid(0).rotationEffect(.degrees(peelL || reduceMotion ? -7 : 0))
                .modifier(Peel(shown: peelL, dx: 96, dy: -150, reduce: reduceMotion))
                .place(16, top, w: pw, align: .leading)
            polaroid(1).rotationEffect(.degrees(peelR || reduceMotion ? 6.5 : 0))
                .modifier(Peel(shown: peelR, dx: -96, dy: -164, reduce: reduceMotion))
                .place(W - 16 - pw, top + 18, w: pw, align: .trailing)
        }
    }

    private func polaroid(_ idx: Int) -> some View {
        let img = model.polaroids.indices.contains(idx) ? model.polaroids[idx] : nil
        return Group {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else { Rectangle().fill(a.tint) }
        }
        .frame(width: 132, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(EdgeInsets(top: 9, leading: 9, bottom: 22, trailing: 9))
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: a.deep.opacity(0.4), radius: 13, y: 11)
    }

    private var kickerLayer: some View {
        HStack(spacing: 12) {
            if !model.content.kickerPrefix.isEmpty {
                Text(model.content.kickerPrefix).font(PosterFont.caveat(27)).foregroundStyle(a.deep).rotationEffect(.degrees(-5))
            }
            Text(model.content.kickerText)
                .font(PosterFont.baloo(31)).tracking(0.9).foregroundStyle(PosterPurpose.cream)
                .padding(.horizontal, 26).padding(.vertical, 10)
                .background(a.accent, in: Capsule())
                .rotationEffect(.degrees(-1.5))
        }
        .modifier(Slam(shown: kickerIn, reduce: reduceMotion))
        .place(m, 96, w: W - 2 * m)
    }

    @ViewBuilder
    private var nameLayer: some View {
        Group {
            switch model.purpose {
            case .missing:
                Text(model.content.name).font(PosterFont.baloo(88)).foregroundStyle(a.deep)
                    .lineLimit(1).minimumScaleFactor(0.5).creamHalo(a.deep).rotationEffect(.degrees(1))
                    .place(20, 404, w: W - 40)
            case .found:
                Text(model.content.headlineQuestion).font(PosterFont.baloo(46)).foregroundStyle(a.deep)
                    .creamHalo(a.deep).rotationEffect(.degrees(1))
                    .place(24, 156, w: W - 48)
            case .adopt:
                VStack(spacing: 7) {
                    Text(model.content.name).font(PosterFont.baloo(76)).foregroundStyle(a.deep)
                        .lineLimit(1).minimumScaleFactor(0.5).padding(.vertical, -12).creamHalo(a.deep).rotationEffect(.degrees(1))
                    if !model.content.akaLine.isEmpty {
                        Text(model.content.akaLine).font(PosterFont.caveat(20)).foregroundStyle(a.deep.opacity(0.85)).multilineTextAlignment(.center).fixedSize(horizontal: true, vertical: false)
                    }
                }
                .place(24, 150, w: W - 48)
            }
        }
        .modifier(Slam(shown: nameIn, reduce: reduceMotion))
        .zIndex(3)
    }

    private var chipLayer: some View {
        HStack(spacing: 9) {
            ForEach(Array(model.chips.enumerated()), id: \.offset) { i, text in
                Text(text).font(PosterFont.nunito(13.5)).tracking(0.4).foregroundStyle(a.deep)
                    .padding(.horizontal, 17).padding(.vertical, 8)
                    // Same frosted-glass background the final poster uses, so the
                    // chips carry the glass while they pop into place — not a
                    // solid tint that snaps to glass at the end.
                    .background {
                        Capsule().fill(.white.opacity(0.45))
                            .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                            .shadow(color: a.deep.opacity(0.12), radius: 4, y: 2)
                    }
                    .modifier(Pop(shown: i < chip.count ? chip[i] : true, reduce: reduceMotion))
            }
        }
        .place(m, 520, w: W - 2 * m).zIndex(3)
    }

    // Simplified block during assembly (real PosterView covers it at the end).
    private var blockLayer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.content.blockLeftLabel).font(PosterFont.nunito(10.5)).tracking(1.9).foregroundStyle(model.purpose.eyebrow)
                    Text(model.content.blockLeftBig).font(PosterFont.baloo(model.content.blockBigOnRight ? 20 : 30)).foregroundStyle(model.content.blockBigOnRight ? PosterPurpose.ink : a.accent).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(width: W - 2 * m, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: a.deep.opacity(0.4), radius: 12, y: 12)
        .modifier(Pop(shown: blockIn, reduce: reduceMotion))
        .place(m, 568, w: W - 2 * m)
    }

    private var barLayer: some View {
        HStack {
            Text(model.content.contactLabel).font(PosterFont.nunito(11.5)).tracking(1.4).lineSpacing(2).foregroundStyle(a.tint)
            Spacer(minLength: 0)
            Text(model.content.phone.isEmpty ? "Your number" : model.content.phone)
                .font(PosterFont.baloo(28)).foregroundStyle(PosterPurpose.cream).monospacedDigit()
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .frame(width: W - 2 * m)
        .background(a.deep, in: RoundedRectangle(cornerRadius: 32))
        .modifier(Pop(shown: barIn, reduce: reduceMotion))
        .place(m, 780, w: W - 2 * m)
    }

    private var sigLayer: some View {
        HStack(spacing: 7) {
            PosterPaw(color: model.purpose.sigPaw, width: 17)
            Text("MADE WITH DOGGOCOLLECTOR").font(PosterFont.nunito(10)).tracking(1).foregroundStyle(model.purpose.eyebrow)
        }
        .opacity(sigIn || reduceMotion && sigIn ? 1 : 0)
        .offset(y: sigIn ? 0 : 10)
        .place(m, 734, w: W - 2 * m, align: .trailing)
    }

    private let m: CGFloat = 26

    // MARK: - Timeline

    private func run() async {
        // A beat after the view settles so flipping swarmStarted is a real
        // state change the KeyframeAnimators pick up (not coalesced with the
        // first render).
        await sleep(0.05); hLight.toggle()
        withAnimation(.linear(duration: 5.15)) { progress = 1 }

        // The photos have flown from their exact grid cells into the ring
        // (matched geometry, during the pre-flight → ceremony transition). Let
        // that flight settle, then orbit, then collapse the ring into a deck.
        await sleep(0.50)                                                    // 0.55 flight settled
        if !reduceMotion { withAnimation(.easeInOut(duration: 1.35)) { orbitAngle = 1.7 } }
        await sleep(1.35)                                                    // 1.90 orbit
        withAnimation(.easeIn(duration: 0.30)) { swarmR = 0 }                // deck converges
        withAnimation(.easeOut(duration: 0.62)) { flashIn = true }
        await sleep(0.20); hRigid.toggle()                                   // ~2.15 deck lands
        await sleep(0.09)
        withAnimation(.timingCurve(0.2, 0.86, 0.3, 1, duration: 0.72)) { heroIn = true }   // 2.24
        withAnimation(.easeOut(duration: 0.4)) { swarmFade = true }          // deck fades as the dog lifts
        await sleep(0.64)                                                    // 2.88 colour floods
        withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.56)) { washIn = true }
        // The ground also floods the strip below the card so there's no dark
        // band under it once it's built (it blends into the editor's ground).
        withAnimation(.easeInOut(duration: 0.6)) { bgGround = true }
        await sleep(0.08); hSoft.toggle()                                    // 2.96 dog lifts
        await sleep(0.16); withAnimation(peelCurve) { peelL = true }         // 3.12
        await sleep(0.11); withAnimation(peelCurve) { peelR = true }         // 3.23
        // Assembly — deliberately unhurried so it's admirable, a beat between
        // each element landing (kicker → name climax → chips → block → bar).
        await sleep(0.32); withAnimation(slamSpring) { kickerIn = true }     // 3.55
        await sleep(0.22); withAnimation(slamSpring) { nameIn = true }; hHeavy.toggle()   // 3.77 climax
        await sleep(0.30); withAnimation(popSpring) { chip[0] = true }       // 4.07
        await sleep(0.13); withAnimation(popSpring) { chip[1] = true }       // 4.20
        await sleep(0.13); withAnimation(popSpring) { chip[2] = true }       // 4.33
        await sleep(0.10); withAnimation(popSpring) { blockIn = true }       // 4.43
        await sleep(0.17); withAnimation(popSpring) { barIn = true }         // 4.60
        await sleep(0.17); withAnimation(.easeOut(duration: 0.42)) { sigIn = true }   // 4.77
        await sleep(0.13); withAnimation(.easeOut(duration: 0.4)) { realPosterIn = true }   // 4.90
        await sleep(0.12); hSuccess.toggle()                                 // 5.02 settle
        await sleep(0.28); finish()                                          // 5.30
    }

    private func skip() {
        guard !didFinish else { return }
        withAnimation(.easeInOut(duration: 0.26)) { realPosterIn = true; progress = 1 }
        hHeavy.toggle()
        Task { await sleep(0.26); finish() }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }

    private func sleep(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    private var peelCurve: Animation { .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.56) }
    private var slamSpring: Animation { .spring(response: 0.42, dampingFraction: 0.64) }
    private var popSpring: Animation { .spring(response: 0.38, dampingFraction: 0.68) }

    struct FlashFrame { var scale: CGFloat; var opacity: Double }
}

// MARK: - Entrance modifiers

/// heroLift: translateY 46→0, scale .8→1, blur 9→0.
private struct HeroLift: ViewModifier {
    let shown: Bool
    let reduce: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: shown || reduce ? 0 : 9)
            .scaleEffect(shown || reduce ? 1 : 0.8)
            .offset(y: shown || reduce ? 0 : 46)
            .opacity(shown ? 1 : 0)
    }
}

/// peel: from (dx,dy) offset + scale .5→1.
private struct Peel: ViewModifier {
    let shown: Bool
    let dx: CGFloat
    let dy: CGFloat
    let reduce: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduce ? 1 : 0.5)
            .offset(x: shown || reduce ? 0 : dx, y: shown || reduce ? 0 : dy)
            .opacity(shown ? 1 : 0)
    }
}

/// slam: scale 1.7→1 (the spring supplies the .965 overshoot).
private struct Slam: ViewModifier {
    let shown: Bool
    let reduce: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduce ? 1 : (reduce ? 1 : 1.7))
            .opacity(shown ? 1 : 0)
    }
}

/// pop: scale .7→1 (spring overshoots to ~1.04) + translateY 8→0.
private struct Pop: ViewModifier {
    let shown: Bool
    let reduce: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduce ? 1 : (reduce ? 1 : 0.7))
            .offset(y: shown || reduce ? 0 : 8)
            .opacity(shown ? 1 : 0)
    }
}

private extension View {
    func place(_ x: CGFloat, _ y: CGFloat, w: CGFloat, align: Alignment = .center) -> some View {
        self.frame(width: w, alignment: align).offset(x: x, y: y)
    }
    func creamHalo(_ deep: Color) -> some View {
        self.shadow(color: PosterPurpose.cream, radius: 0, y: 3)
            .shadow(color: deep.opacity(0.26), radius: 11, y: 10)
    }
}
