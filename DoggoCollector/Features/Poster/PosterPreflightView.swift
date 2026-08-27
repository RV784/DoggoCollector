//
//  PosterPreflightView.swift
//  DoggoCollector
//
//  The pre-flight screen (the studio's idle state) — every photo of the dog
//  already in the app goes into the source set, a 4-up grid led by a
//  "+ From gallery" tile, purpose chips, and "Make the poster". Styling is the
//  design's own (dark #1B1611 studio surface).
//

import SwiftUI
import PhotosUI

struct PosterPreflightView: View {
    let dog: CaughtDog
    let photos: [DogPhoto]
    @Binding var purpose: PosterPurpose
    @Binding var heroPhotoID: UUID?
    @Binding var pickerItems: [PhotosPickerItem]
    var isImporting: Bool
    /// Shared with the ceremony's swarm so each grid photo flies from its exact
    /// cell into the orbit (matched geometry). nil in isolated previews.
    var tileNS: Namespace.ID
    var onMake: () -> Void
    var onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    private var heroID: UUID? { heroPhotoID ?? dog.coverPhoto?.id }

    var body: some View {
        ZStack {
            Color(hex: 0x1B1611).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topRow
                    .padding(.bottom, 22)

                Text("Make a poster\nfor \(dog.name)")
                    .font(PosterFont.baloo(29))
                    .foregroundStyle(Color(hex: 0xFFF6E7))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Every photo of \(dog.name) in the app goes in. We read their colour, size, ears, tail and collar off all of them \u{2014} you can change anything after.")
                    .font(PosterFont.nunito(13.5, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8E7D64))
                    .lineSpacing(3)
                    .padding(.top, 8)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 7) {
                        fromGalleryTile
                        ForEach(photos) { photo in
                            photoTile(photo)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                }

                purposeChips
                    .padding(.top, 4)

                Button(action: onMake) {
                    Text("Make the poster")
                        .font(PosterFont.baloo(19))
                        .foregroundStyle(Color(hex: 0x2B2013))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(DoggoColor.marigold, in: RoundedRectangle(cornerRadius: 30))
                        .shadow(color: DoggoColor.marigold.opacity(0.9), radius: 17, y: 9)
                }
                .buttonStyle(ScalePressButtonStyle())
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var topRow: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xEFE3D2))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            Spacer()
            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s") on file")
                .font(PosterFont.nunito(13, weight: .extraBold))
                .foregroundStyle(Color(hex: 0x8E7D64))
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
    }

    private var fromGalleryTile: some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: nil, matching: .images) {
            VStack(spacing: 3) {
                if isImporting {
                    ProgressView().tint(Color(hex: 0xC3B49B))
                } else {
                    Text("+").font(.system(size: 20, weight: .regular)).foregroundStyle(Color(hex: 0xC3B49B))
                    Text("FROM\nGALLERY")
                        .font(PosterFont.nunito(8.5)).tracking(0.8)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(hex: 0x8E7D64))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .foregroundStyle(Color.white.opacity(0.3)))
        }
        .disabled(isImporting)
    }

    private func photoTile(_ photo: DogPhoto) -> some View {
        Button { heroPhotoID = photo.id } label: {
            Color.clear
                .frame(height: 74)
                .overlay {
                    if let img = PhotoDecoder.image(from: photo.imageData, size: .tile, cacheKey: photo.id.uuidString) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        PolkaDotPlaceholder(seed: photo.id.hashValue)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if photo.id == heroID {
                        badge("HERO")
                    }
                }
                .overlay {
                    if photo.id == heroID {
                        RoundedRectangle(cornerRadius: 10).stroke(DoggoColor.marigold, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        // The source each swarm tile flies out of in the ceremony.
        .matchedGeometryEffect(id: "swarmtile-\(photo.id)", in: tileNS, isSource: true)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(PosterFont.nunito(8.5)).tracking(1)
            .foregroundStyle(Color(hex: 0x2B2013))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(DoggoColor.marigold, in: RoundedRectangle(cornerRadius: 5))
            .padding(6)
    }

    private var purposeChips: some View {
        HStack(spacing: 8) {
            ForEach(PosterPurpose.allCases, id: \.self) { p in
                let active = p == purpose
                Text(active ? "Purpose \u{00B7} \(p.title)" : p.title)
                    .font(PosterFont.nunito(12, weight: .extraBold))
                    .foregroundStyle(active ? Color(hex: 0x17110B) : Color(hex: 0xC3B49B))
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFFF6E7))
                        } else {
                            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.14), lineWidth: 1))
                        }
                    }
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { purpose = p } }
            }
            Spacer(minLength: 0)
        }
    }
}
