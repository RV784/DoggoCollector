//
//  PosterEditView.swift
//  DoggoCollector
//
//  The finished-poster state — the real poster with the edit bar overlaid at
//  the bottom (Edit details / Layout / Colour / Number / Add a line) and
//  Share / Replay. The poster is the form: every accent, layout and field is
//  curated so a guardian cannot produce an unreadable poster (spec §11).
//  Editing mutates the persisted `Poster`; the poster re-renders live.
//

import SwiftUI

struct PosterEditView: View {
    @Bindable var poster: Poster
    let heroImage: UIImage?
    let polaroids: [UIImage?]
    let photos: [DogPhoto]
    var onShare: () -> Void
    var onClose: () -> Void
    var onPickHero: (UUID) -> Void

    @State private var sheet: EditSheet?
    @State private var showChrome = false

    enum EditSheet: Int, Identifiable { case details, colour, layout, addLine, hero; var id: Int { rawValue } }

    private var model: PosterRenderModel {
        PosterRenderModel(
            purpose: poster.purpose,
            accent: poster.purpose.accent(poster.accentIndex),
            layout: poster.layout,
            content: poster.content,
            chips: poster.visibleChips.map(\.text),
            hero: heroImage,
            polaroids: polaroids,
            numberVisible: poster.numberVisible)
    }

    private let tools: [(String, EditSheet?)] = [
        ("Edit details", .details), ("Layout", .layout), ("Colour", .colour),
        ("Hero photo", .hero), ("Add a line", .addLine)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // The poster's own bottom ground colour fills the screen so there's
            // no black band below the poster — it reads as full-screen and the
            // poster's bottom edge blends seamlessly into it.
            (model.accent.grounds.last ?? DoggoColor.cream).ignoresSafeArea()

            GeometryReader { geo in
                let scale = geo.size.width / PosterView.width
                PosterView(model: model)
                    .frame(width: PosterView.width, height: PosterView.height)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: geo.size.width, height: PosterView.height * scale, alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea(edges: .top)

            // The card is already in its final place (the ceremony left it here),
            // so only the chrome animates in — the edit bar rises up, the close
            // button fades in.
            if showChrome {
                editBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if showChrome {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PosterPurpose.ink)
                        .glassCircleChrome(size: 38)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16).padding(.top, 8)
                .transition(.opacity)
            }
        }
        .sheet(item: $sheet) { which in
            sheetContent(which)
                .presentationDetents(which == .details ? [.large] : [.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05)) {
                showChrome = true
            }
        }
    }

    // MARK: - Edit bar

    private var editBar: some View {
        VStack(spacing: 11) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
                        Button { if let s = tool.1 { sheet = s } } label: {
                            toolLabel(Text(tool.0))
                        }
                        .buttonStyle(.plain)
                    }
                    // Number visibility is an inline toggle, not a sheet.
                    Button { withAnimation(.easeOut(duration: 0.2)) { poster.numberVisible.toggle() } } label: {
                        toolLabel(HStack(spacing: 5) {
                            Image(systemName: poster.numberVisible ? "phone.fill" : "qrcode")
                            Text(poster.numberVisible ? "Number" : "QR")
                        })
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
            }

            Button(action: onShare) {
                Text("Share to status")
                    .font(PosterFont.baloo(18)).foregroundStyle(Color(hex: 0x2B2013))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(DoggoColor.marigold, in: RoundedRectangle(cornerRadius: 27))
                    .shadow(color: DoggoColor.marigold.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(ScalePressButtonStyle())
            .padding(.horizontal, 18)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    /// A Liquid-Glass edit-bar pill (the bar floats over the poster's ground,
    /// so real `.glassEffect` renders correctly here — unlike the poster
    /// itself, which is rasterized for export).
    private func toolLabel<V: View>(_ content: V) -> some View {
        content
            .font(PosterFont.nunito(13, weight: .extraBold))
            .foregroundStyle(PosterPurpose.ink)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ which: EditSheet) -> some View {
        switch which {
        case .details: PosterDetailsSheet(poster: poster)
        case .colour: PosterColourSheet(poster: poster)
        case .layout: PosterLayoutSheet(poster: poster)
        case .addLine: PosterAddLineSheet(poster: poster)
        case .hero: PosterHeroSheet(photos: photos, selectedID: poster.heroPhotoID) { onPickHero($0) }
        }
    }
}

// MARK: - Colour sheet

private struct PosterColourSheet: View {
    @Bindable var poster: Poster
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colour").font(PosterFont.baloo(22)).foregroundStyle(DoggoColor.ink)
            Text("Five accents, each on its own matched ground.")
                .font(DoggoTextStyle.caption).foregroundStyle(DoggoColor.inkMuted)
            HStack(spacing: 12) {
                ForEach(Array(poster.purpose.accents.enumerated()), id: \.offset) { i, accent in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { poster.accentIndex = i }
                    } label: {
                        RoundedRectangle(cornerRadius: 12).fill(accent.accent)
                            .frame(width: 46, height: 46)
                            .overlay {
                                if i == poster.accentIndex {
                                    RoundedRectangle(cornerRadius: 12).stroke(DoggoColor.ink, lineWidth: 3)
                                        .padding(-3).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            Spacer()
        }
        .padding(24)
        .background(DoggoColor.cream.ignoresSafeArea())
    }
}

// MARK: - Layout sheet

private struct PosterLayoutSheet: View {
    @Bindable var poster: Poster
    private let options: [(PosterLayout, String)] = [
        (.heroCentred, "Hero centred"), (.heroRight, "Hero right"), (.photoLed, "Photo-led")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Layout").font(PosterFont.baloo(22)).foregroundStyle(DoggoColor.ink)
            Text("Photo-led uses no cutout \u{2014} best when the background is busy.")
                .font(DoggoTextStyle.caption).foregroundStyle(DoggoColor.inkMuted)
            ForEach(options, id: \.0) { opt in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { poster.layout = opt.0 }
                } label: {
                    HStack {
                        Text(opt.1).font(DoggoTextStyle.bodySemibold).foregroundStyle(DoggoColor.ink)
                        Spacer()
                        if poster.layout == opt.0 { Image(systemName: "checkmark").foregroundStyle(DoggoColor.marigold) }
                    }
                    .padding(14)
                    .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(poster.layout == opt.0 ? DoggoColor.marigold : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(24)
        .background(DoggoColor.cream.ignoresSafeArea())
    }
}

// MARK: - Add-a-line sheet

private struct PosterAddLineSheet: View {
    @Bindable var poster: Poster
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a line").font(PosterFont.baloo(22)).foregroundStyle(DoggoColor.ink)
            Text("One handwritten line \u{2014} it rides in the caption on stories, and onto the poster on the 4:5 export.")
                .font(DoggoTextStyle.caption).foregroundStyle(DoggoColor.inkMuted)
            TextField("e.g. He loves everyone he meets", text: $text, axis: .vertical)
                .font(PosterFont.caveat(22))
                .padding(12)
                .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DoggoColor.inputBorder, lineWidth: 1.5))
                .onChange(of: text) { _, v in
                    if v.count > 90 { text = String(v.prefix(90)) }
                    poster.content.freeLine = text
                }
            Text("\(text.count)/90").font(DoggoTextStyle.caption).foregroundStyle(DoggoColor.inkMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer()
        }
        .padding(24)
        .background(DoggoColor.cream.ignoresSafeArea())
        .onAppear { text = poster.content.freeLine }
    }
}

// MARK: - Details sheet (the poster's editable copy)

private struct PosterDetailsSheet: View {
    @Bindable var poster: Poster

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if poster.purpose != .found {
                        field("Name", $poster.content.name)
                    }
                    if poster.purpose == .adopt {
                        field("Aka line", $poster.content.akaLine)
                    }
                }

                Section(headerFor) {
                    field(poster.content.blockLeftLabel.capitalizedFirst, $poster.content.blockLeftBig)
                    if !poster.content.blockLeftSmall.isEmpty || poster.purpose != .adopt {
                        field("Time", $poster.content.blockLeftSmall)
                    }
                    field(poster.content.blockRightLabel.capitalizedFirst, $poster.content.blockRightValue)
                    if poster.purpose == .adopt {
                        field("City note", $poster.content.blockRightSmall)
                    }
                }

                Section("What to say") {
                    field("Main line", $poster.content.blockBottomText)
                    if poster.content.blockBottomStyle == .textChip {
                        field("Tag", $poster.content.blockBottomChip)
                    }
                    HStack {
                        field("Badge", $poster.content.badgeValue).frame(maxWidth: 120)
                        field("Unit", $poster.content.badgeUnit)
                    }
                }

                Section("Contact") {
                    field("Phone number", $poster.content.phone).keyboardType(.phonePad)
                    field("Caption", $poster.content.contactCaption)
                }
            }
            .navigationTitle("Edit details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerFor: String {
        switch poster.purpose {
        case .missing: return "Last seen"
        case .found: return "Found"
        case .adopt: return "About"
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(DoggoColor.inkMuted)
            TextField(label, text: text, axis: .vertical)
                .font(DoggoTextStyle.bodyRegular)
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let f = first else { return self }
        return f.uppercased() + dropFirst().lowercased()
    }
}

// MARK: - Hero picker sheet

private struct PosterHeroSheet: View {
    let photos: [DogPhoto]
    let selectedID: UUID?
    var onPick: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hero photo").font(PosterFont.baloo(22)).foregroundStyle(DoggoColor.ink)
            Text("The one we lift out as the cutout.").font(DoggoTextStyle.caption).foregroundStyle(DoggoColor.inkMuted)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos) { photo in
                        Button { onPick(photo.id); dismiss() } label: {
                            Color.clear.frame(height: 100)
                                .overlay {
                                    if let img = PhotoDecoder.image(from: photo.imageData, size: .tile, cacheKey: photo.id.uuidString) {
                                        Image(uiImage: img).resizable().scaledToFill()
                                    } else { PolkaDotPlaceholder(seed: photo.id.hashValue) }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(photo.id == selectedID ? DoggoColor.marigold : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .background(DoggoColor.cream.ignoresSafeArea())
    }
}
