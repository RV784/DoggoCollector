//
//  CardDetailView.swift
//  DoggoCollector
//

import SwiftUI

struct CardDetailView: View {
    @Bindable var dog: CaughtDog

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""

    private var serialText: String {
        "#" + String(format: "%03d", dog.serialNumber)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DoggoColor.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(DoggoSpacing.lg)

                ScrollView {
                    VStack(spacing: DoggoSpacing.lg) {
                        DoggoCardView(
                            image: dog.imageData.flatMap(UIImage.init),
                            name: dog.name,
                            breedLabel: dog.breedLabel,
                            serialNumber: dog.serialNumber,
                            traits: dog.traits,
                            placeholderSeed: dog.id.hashValue
                        )

                        Text("\(serialText) in your pack \u{00B7} caught at \(dog.locationLabel)")
                            .font(DoggoTextStyle.caption)
                            .foregroundStyle(DoggoColor.inkMuted)

                        Button {
                            renameText = dog.name
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                                .font(DoggoTextStyle.caption)
                                .foregroundStyle(DoggoColor.marigold)
                        }
                        .buttonStyle(.plain)

                        InsightPanelView(dog: dog)
                    }
                    .padding(.horizontal, DoggoSpacing.lg)
                    .padding(.bottom, 100)
                }
            }

            PillButton(title: "Share this doggo", systemImage: "square.and.arrow.up") {
                showShare = true
            }
            .padding(DoggoSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShare) {
            ShareView(dog: dog)
        }
        .alert("Rename doggo", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dog.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            circleButton("chevron.left", tint: DoggoColor.ink) {
                dismiss()
            }
            Spacer()
            circleButton(dog.isFavorite ? "heart.fill" : "heart", tint: DoggoColor.heartPink) {
                dog.isFavorite.toggle()
            }
        }
    }

    private func circleButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(DoggoColor.cardWhite, in: Circle())
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}
