//
//  PosterView.swift
//  DoggoCollector
//
//  The poster itself — an exact 540×960 rebuild of the v2 poster files
//  (Poster {Missing,Found,Adopt} v2). Authored at 540×960 points; export at 2×
//  gives the 1080×1920 PNG. A pure function of its `PosterRenderModel`, so the
//  same view drives the editor, the ceremony's landing state, and the
//  ImageRenderer export.
//
//  Layout is absolute (the design is `position:absolute`): a fixed
//  ZStack(.topLeading) with each band placed via `.place`. Positions, hexes,
//  fonts and shadows are from ~/Documents/poster_maker_design_extract.md.
//

import SwiftUI

struct PosterView: View {
    let model: PosterRenderModel

    private var p: PosterPurpose { model.purpose }
    private var a: PosterAccent { model.accent }
    private var c: PosterContent { model.content }

    // Canvas
    static let width: CGFloat = 540
    static let height: CGFloat = 960
    private let m: CGFloat = 26   // the shared 26pt side margin
    private let heroW: CGFloat = 404   // cutout hero width (was 372 — enlarged)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground
            cornerBadgeArea
            topRightPaws
            kicker
            headlineArea
            heroArea
            if model.layout != .photoLed { polaroids }
            chipRow
            block
            contactArea
            signature
            taglineView
        }
        .frame(width: Self.width, height: Self.height)
        .clipped()
        .environment(\.colorScheme, .light)
    }

    // MARK: - Ground

    private var ground: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(a.groundGradient)
            // top-left white glow
            RadialGradient(colors: [.white.opacity(0.9), .clear],
                           center: .init(x: 0.22, y: 0.06), startRadius: 0, endRadius: 420)
            // top-right tint glow
            RadialGradient(colors: [p.glowTint.opacity(0.85), .clear],
                           center: .init(x: 0.86, y: 0.30), startRadius: 0, endRadius: 360)
            // corner blob
            Circle()
                .fill(RadialGradient(colors: [p.blobColor.opacity(0.6), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(x: p.blobLeading ? -70 : 310, y: Self.height - 210)
        }
        .frame(width: Self.width, height: Self.height)
    }

    // MARK: - Corner badge (top-left) + paw marks

    @ViewBuilder
    private var cornerBadgeArea: some View {
        if p == .missing {
            VStack(alignment: .leading, spacing: 9) {
                PosterPaw(color: p.pawMarkColor, width: 22)
                badgeCircle(size: 44, valueSize: 19)
            }
            .place(m, 100, w: 60, align: .leading)
        } else {
            badgeCircle(size: 52, valueSize: p == .found ? 17 : 19)
                .place(m, 100, w: 60, align: .leading)
        }
    }

    private func badgeCircle(size: CGFloat, valueSize: CGFloat) -> some View {
        VStack(spacing: -1) {
            Text(c.badgeValue)
                .font(PosterFont.baloo(valueSize))
                .foregroundStyle(a.deep)
            Text(c.badgeUnit)
                .font(PosterFont.nunito(size == 44 ? 7.5 : 8))
                .tracking(1)
                .foregroundStyle(p.badgeLabel)
        }
        .frame(width: size, height: size)
        .background(p.badgeBg, in: Circle())
    }

    private var topRightPaws: some View {
        VStack(alignment: .trailing, spacing: 8) {
            PosterPaw(color: p.pawMarkColor, width: 22).rotationEffect(.degrees(11))
            PosterPaw(color: p.pawMarkColor, width: 17).rotationEffect(.degrees(-14)).opacity(0.75)
        }
        .place(m, 102, w: Self.width - 2 * m, align: .trailing)
    }

    // MARK: - Kicker (band 1)

    private var kicker: some View {
        HStack(spacing: 12) {
            if !c.kickerPrefix.isEmpty {
                Text(c.kickerPrefix)
                    .font(PosterFont.caveat(27))
                    .foregroundStyle(a.deep)
                    .rotationEffect(.degrees(-5))
            }
            Text(c.kickerText)
                .font(PosterFont.baloo(31))
                .tracking(0.9)
                .foregroundStyle(PosterPurpose.cream)
                .padding(.horizontal, 26)
                .padding(.vertical, 7)
                .background(a.accent, in: Capsule())
                .rotationEffect(.degrees(-1.5))
                .shadow(color: a.deep.opacity(0.5), radius: 12, y: 8)
        }
        .place(m, 96, w: Self.width - 2 * m, align: .center)
    }

    // MARK: - Headline / name / sub-line / aka (band 2)

    @ViewBuilder
    private var headlineArea: some View {
        switch p {
        case .missing:
            // sub-line just under the kicker, name over the hero
            Text(c.subLine)
                .font(PosterFont.nunito(13)).tracking(2.6)
                .foregroundStyle(p.eyebrow)
                .place(m, 166, w: Self.width - 2 * m, align: .center)

            Text(c.name)
                .font(PosterFont.baloo(88))
                .foregroundStyle(a.deep)
                .lineLimit(1).minimumScaleFactor(0.5)
                .creamHalo(a.deep)
                .rotationEffect(.degrees(1))
                .place(20, 404, w: Self.width - 40, align: .center)
                .zIndex(3)

        case .found:
            Text(c.headlineQuestion)
                .font(PosterFont.baloo(46))
                .foregroundStyle(a.deep)
                .multilineTextAlignment(.center)
                .creamHalo(a.deep)
                .rotationEffect(.degrees(1))
                .place(24, 162, w: Self.width - 48, align: .center)
                .zIndex(3)

        case .adopt:
            // Name and aka are placed SEPARATELY (not stacked) — a VStack sizes
            // to the aka's ideal width and renders it off-centre + clipped at the
            // poster edge (minimumScaleFactor doesn't scale this custom Caveat
            // face). Explicit centred placement, like the Missing sub-line, is
            // reliable.
            Text(c.name)
                .font(PosterFont.baloo(76))
                .foregroundStyle(a.deep)
                .lineLimit(1).minimumScaleFactor(0.5)
                .creamHalo(a.deep)
                .rotationEffect(.degrees(1))
                .place(20, 150, w: Self.width - 40, align: .center)
                .zIndex(3)

            if !c.akaLine.isEmpty {
                // This Caveat face underreports its glyph advance widths, so
                // SwiftUI computes a too-small intrinsic width and truncates the
                // line inside it (no font size or frame width fixes that).
                // `.fixedSize` disables the compression/truncation entirely — the
                // line draws in full at font 20, which sits comfortably inside the
                // poster width.
                Text(c.akaLine)
                    .font(PosterFont.caveat(20))
                    .foregroundStyle(a.deep.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: false)
                    .place(20, 252, w: Self.width - 40, align: .center)
                    .zIndex(3)
            }
        }
    }

    // MARK: - Hero (band 3)

    private var heroMetrics: (top: CGFloat, height: CGFloat) {
        switch p {
        case .missing: return (190, 322)
        case .found: return (216, 296)
        case .adopt: return (292, 220)
        }
    }

    @ViewBuilder
    private var heroArea: some View {
        let hm = heroMetrics
        if model.layout == .photoLed {
            // No cutout: a white-mounted photo card, gently tilted, on a soft
            // bloom — reads as an intentional hero shot rather than a raw slab.
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.9), p.glowTint.opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: 230))
                    .frame(width: Self.width - 24, height: hm.height + 70)
                heroImage(fill: true)
                    .frame(width: Self.width - 88, height: hm.height + 6)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(11)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .shadow(color: a.deep.opacity(0.3), radius: 16, y: 13)
                    .rotationEffect(.degrees(-1.4))
            }
            .frame(width: Self.width, height: hm.height + 70)
            .place(0, hm.top - 12, w: Self.width, align: .center)
        } else {
            ZStack {
                // soft white bloom behind the cutout
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.92), p.glowTint.opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: 214))
                    .frame(width: heroW, height: hm.height)
                heroImage(fill: false)
                    .frame(width: heroW, height: hm.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.82),
                            .init(color: .black.opacity(0.35), location: 0.94),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: a.deep.opacity(0.3), radius: 14, y: 15)
            }
            .frame(width: heroW, height: hm.height)
            .place((Self.width - heroW) / 2, hm.top, w: heroW, align: .center)
        }
    }

    @ViewBuilder
    private func heroImage(fill: Bool) -> some View {
        if let hero = model.hero {
            Image(uiImage: hero)
                .resizable()
                .aspectRatio(contentMode: fill ? .fill : .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        } else {
            // A valid poster still gets made — a soft placeholder bloom.
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.white.opacity(0.55), a.tint.opacity(0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(a.accent.opacity(0.25))
                )
        }
    }

    // MARK: - Polaroids (band 4)

    private var polaroids: some View {
        let top: CGFloat = p == .missing ? 310 : (p == .found ? 306 : 306)
        let pw: CGFloat = 150   // outer mount width (was 136)
        return ZStack(alignment: .topLeading) {
            polaroid(model.polaroids.first ?? nil, tint: a.tint)
                .rotationEffect(.degrees(-7))
                .place(16, top - 4, w: pw, align: .leading)
            polaroid(model.polaroids.count > 1 ? model.polaroids[1] : nil, tint: a.tint)
                .rotationEffect(.degrees(6.5))
                .place(Self.width - 16 - pw, top + 18, w: pw, align: .trailing)
        }
    }

    private func polaroid(_ image: UIImage?, tint: Color) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(tint)
            }
        }
        .frame(width: 132, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(EdgeInsets(top: 9, leading: 9, bottom: 22, trailing: 9))
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: a.deep.opacity(0.4), radius: 13, y: 11)
    }

    // MARK: - Trait chips (band 5)

    private var chipRow: some View {
        HStack(spacing: 9) {
            ForEach(Array(model.chips.enumerated()), id: \.offset) { i, text in
                Text(text)
                    .font(PosterFont.nunito(13.5)).tracking(0.4)
                    .foregroundStyle(chipIsAccent(i) ? PosterPurpose.cream : a.deep)
                    .padding(.horizontal, 17).padding(.vertical, 8)
                    .background { chipBackground(accentFilled: chipIsAccent(i)) }
            }
        }
        .place(m, 520, w: Self.width - 2 * m, align: .center)
        .zIndex(3)
    }

    /// A frosted-glass chip: translucent so the name/photo it overlaps reads
    /// THROUGH it (the intended overlap look), with a soft top highlight + a
    /// hairline edge for the glass read. Uses translucent fills rather than a
    /// real `.glassEffect` on purpose — the poster is rasterized by
    /// ImageRenderer for export, which can't capture live glass material.
    @ViewBuilder
    private func chipBackground(accentFilled: Bool) -> some View {
        if accentFilled {
            Capsule().fill(a.accent)
        } else {
            Capsule()
                .fill(.white.opacity(0.45))
                .overlay(
                    Capsule().fill(
                        LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom))
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                .shadow(color: a.deep.opacity(0.12), radius: 4, y: 2)
        }
    }

    /// One chip may be accent-filled to highlight a key trait (Found's collar,
    /// Adopt's behavioural), matching the poster files.
    private func chipIsAccent(_ index: Int) -> Bool {
        (p == .found || p == .adopt) && index == 2 && model.chips.count >= 3
    }

    // MARK: - The one block (band 6)

    private var block: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                if c.blockBigOnRight {
                    blockNeedsColumn.frame(maxWidth: .infinity, alignment: .leading)
                    divider
                    blockCityColumn
                } else {
                    blockDateColumn
                    divider
                    blockPlaceColumn.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // Bound the row to its tallest column so the stretch-divider
            // (maxHeight:.infinity) matches the row instead of the whole canvas.
            .fixedSize(horizontal: false, vertical: true)
            blockBottom
        }
        .padding(EdgeInsets(top: 15, leading: 20, bottom: 14, trailing: 20))
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: a.deep.opacity(0.42), radius: 16, y: 14)
        .place(m, 568, w: Self.width - 2 * m, align: .center)
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1).fill(a.tint).frame(width: 2).frame(maxHeight: .infinity)
    }

    private func eyebrow(_ t: String) -> some View {
        Text(t).font(PosterFont.nunito(10.5)).tracking(1.9).foregroundStyle(p.eyebrow)
    }

    // Missing/Found: date on the left (fixed), place on the right (flex).
    private var blockDateColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            eyebrow(c.blockLeftLabel)
            Text(c.blockLeftBig).font(PosterFont.baloo(36)).foregroundStyle(a.accent)
            if !c.blockLeftSmall.isEmpty {
                Text(c.blockLeftSmall).font(PosterFont.nunito(14, weight: .extraBold)).foregroundStyle(Color(hex: 0x7A5B49))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var blockPlaceColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            eyebrow(c.blockRightLabel)
            Text(c.blockRightValue.isEmpty ? "Tap to add" : c.blockRightValue)
                .font(PosterFont.baloo(21)).foregroundStyle(PosterPurpose.ink)
                .lineSpacing(2)
        }
    }

    // Adopt: needs on the left (flex), city on the right (fixed).
    private var blockNeedsColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            eyebrow(c.blockLeftLabel)
            Text(c.blockLeftBig).font(PosterFont.baloo(21)).foregroundStyle(PosterPurpose.ink).lineSpacing(2)
        }
    }

    private var blockCityColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            eyebrow(c.blockRightLabel)
            Text(c.blockRightValue).font(PosterFont.baloo(36)).foregroundStyle(a.accent)
            if !c.blockRightSmall.isEmpty {
                Text(c.blockRightSmall).font(PosterFont.nunito(14, weight: .extraBold)).foregroundStyle(Color(hex: 0x7A6448))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var blockBottom: some View {
        switch c.blockBottomStyle {
        case .none:
            EmptyView()
        case .checkPill:
            HStack(spacing: 11) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(width: 26, height: 26).background(a.accent, in: Circle())
                Text(c.blockBottomText).font(PosterFont.baloo(21)).foregroundStyle(a.deep)
            }
            .padding(.horizontal, 15).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(a.tint.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
            .padding(.top, 13)
        case .textChip:
            VStack(alignment: .leading, spacing: 4) {
                if !c.blockBottomLabel.isEmpty { eyebrow(c.blockBottomLabel) }
                HStack(alignment: .center, spacing: 10) {
                    Text(c.blockBottomText).font(PosterFont.baloo(21)).foregroundStyle(PosterPurpose.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !c.blockBottomChip.isEmpty {
                        Text(c.blockBottomChip)
                            .font(PosterFont.nunito(13)).foregroundStyle(bottomChipFg)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(bottomChipBg, in: Capsule())
                            .fixedSize()
                    }
                }
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(a.tint.opacity(0.6)).frame(height: 2).offset(y: 1)
            }
        }
    }

    // Adopt's "all clear" is a green chip; Missing's "no collar" uses the tint.
    private var bottomChipBg: Color { p == .adopt ? Color(hex: 0xE7F5E4) : a.tint }
    private var bottomChipFg: Color { p == .adopt ? Color(hex: 0x417F46) : a.deep }

    // MARK: - Contact bar (band 7) / QR

    @ViewBuilder
    private var contactArea: some View {
        if model.numberVisible {
            HStack(alignment: .center, spacing: 14) {
                Text(c.contactLabel)
                    .font(PosterFont.nunito(11.5)).tracking(1.4).lineSpacing(2)
                    .foregroundStyle(a.tint)
                    .fixedSize()
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(c.phone.isEmpty ? "Add your number" : c.phone)
                        .font(PosterFont.baloo(c.phone.isEmpty ? 22 : 31))
                        .foregroundStyle(c.phone.isEmpty ? PosterPurpose.cream.opacity(0.6) : PosterPurpose.cream)
                        .monospacedDigit()
                    if !c.contactCaption.isEmpty {
                        Text(c.contactCaption)
                            .font(PosterFont.nunito(11.5, weight: .bold))
                            .foregroundStyle(PosterPurpose.cream.opacity(0.78))
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(a.deep, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: a.deep.opacity(0.7), radius: 15, y: 12)
            .place(m, 780, w: Self.width - 2 * m, align: .center)
        } else {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12).fill(PosterPurpose.cream)
                    .frame(width: 74, height: 74)
                    .overlay(Image(systemName: "qrcode").font(.system(size: 54)).foregroundStyle(a.deep))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAT IN THE APP").font(PosterFont.nunito(11.5)).tracking(1.4).foregroundStyle(a.tint)
                    Text("Scan to message me").font(PosterFont.baloo(20)).foregroundStyle(PosterPurpose.cream)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(a.deep, in: RoundedRectangle(cornerRadius: 32))
            .place(m, 780, w: Self.width - 2 * m, align: .center)
        }
    }

    // MARK: - Signature + tagline

    // Signature + tagline live in the bottom corners, below the contact bar
    // (per user request — the design tucked them just above it, which crowded
    // the contact section).
    private var signature: some View {
        HStack(spacing: 7) {
            PosterPaw(color: p.sigPaw, width: 16)
            Text("MADE WITH DOGGOCOLLECTOR")
                .font(PosterFont.nunito(9.5)).tracking(1)
                .foregroundStyle(p.eyebrow)
        }
        .place(m, 906, w: Self.width - 2 * m, align: .trailing)
    }

    private var taglineView: some View {
        Text(p.tagline)
            .font(PosterFont.nunito(9.5)).tracking(1)
            .foregroundStyle(p.taglineColor)
            .place(m, 908, w: Self.width - 2 * m, align: .leading)
    }
}

// MARK: - Helpers

private extension View {
    /// Absolute placement inside a fixed ZStack(.topLeading): a `w`-wide frame
    /// (content aligned by `align`) whose top-leading is offset to (x, y).
    func place(_ x: CGFloat, _ y: CGFloat, w: CGFloat, align: Alignment = .center) -> some View {
        self.frame(width: w, alignment: align).offset(x: x, y: y)
    }

    /// The design's 6px cream halo — a soft cream text-shadow, not a hard drop.
    func creamHalo(_ deep: Color) -> some View {
        self
            .shadow(color: PosterPurpose.cream, radius: 0, y: 3)
            .shadow(color: deep.opacity(0.26), radius: 11, y: 10)
    }
}

/// The five-ellipse paw, drawn in its 22×20 base space and scaled to `width`.
struct PosterPaw: View {
    let color: Color
    let width: CGFloat
    private var s: CGFloat { width / 22 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ellipse(0, 4, 6, 8.5, -22)
            ellipse(5.8, 0, 6, 9, -7)
            ellipse(12.2, 0, 6, 9, 7)
            ellipse(17.5, 4, 6, 8.5, 22)
            ellipse(4.5, 10, 13, 10, 0)   // pad
        }
        .frame(width: 22 * s, height: 20 * s, alignment: .topLeading)
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rot: Double) -> some View {
        Ellipse().fill(color)
            .frame(width: w * s, height: h * s)
            .rotationEffect(.degrees(rot))
            .offset(x: x * s, y: y * s)
    }
}
