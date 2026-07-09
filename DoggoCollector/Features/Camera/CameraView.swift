//
//  CameraView.swift
//  DoggoCollector
//
//  Presented as a `matchedGeometryEffect` morph from Collection's
//  "Catch a doggo" pill — the pill grows into a bottom-anchored viewfinder
//  panel (not full screen), matching the reference camera-menu-expand
//  pattern. The shape/frame/namespace tagging live on the caller
//  (CollectionView) since both the pill and this panel share one surface.
//

import SwiftUI
import SwiftData

struct CameraView: View {
    var onClose: () -> Void
    var onCaught: (CaughtDog) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CameraViewModel()
    @State private var showMissBanner = false
    @AppStorage("hasSeenCameraSafetyTip") private var hasSeenSafetyTip = false

    var body: some View {
        ZStack {
            if viewModel.cameraService.isAuthorized {
                CameraPreviewView(session: viewModel.cameraService.session)
            } else {
                Color.black
            }

            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: DoggoSpacing.lg) {
                topBar

                Spacer()

                VStack(spacing: DoggoSpacing.md) {
                    // Square (matches the app-wide square-photo standard —
                    // the capture is center-cropped to a square, so what
                    // this bracket frames is what the saved/displayed photo
                    // actually keeps). Deliberately kept at its original
                    // fixed size, not sized to the panel's width — the
                    // panel's height is fixed/tuned for the pill→panel→card
                    // morph, and a bigger bracket was found (via on-device
                    // testing) to overflow that budget and push the shutter
                    // button off-screen.
                    ViewfinderBracket()
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 170, height: 170)

                    Text(showMissBanner ? "No dog spotted — try again!" : "Point at a doggo")
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }

                Spacer()

                if !hasSeenSafetyTip {
                    safetyTipCard
                }

                bottomBar
            }
            .padding(.horizontal, DoggoSpacing.lg)
            .padding(.top, DoggoSpacing.lg)
            .padding(.bottom, DoggoSpacing.xl)
        }
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: DoggoSpacing.xs) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("LIVE")
                    .font(DoggoTextStyle.eyebrow)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, DoggoSpacing.md)
            .padding(.vertical, DoggoSpacing.sm)
            .background(.black.opacity(0.35), in: Capsule())

            Spacer()

            Button(action: viewModel.replayWhistle) {
                VStack(spacing: DoggoSpacing.xs) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DoggoColor.ink)
                        .frame(width: 44, height: 44)
                        .background(DoggoColor.cream, in: Circle())
                    Text("Whistle")
                        .font(DoggoTextStyle.caption)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScalePressButtonStyle())
        }
    }

    private var safetyTipCard: some View {
        HStack(alignment: .top, spacing: DoggoSpacing.sm) {
            ScoutMascot(expression: .idle, size: 36)
            VStack(alignment: .leading, spacing: DoggoSpacing.xs) {
                Text("Don't corner a dog or rush up — let them come to you. And earn a mama dog's trust before saying hi to her pups.")
                    .font(DoggoTextStyle.caption)
                    .foregroundStyle(DoggoColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                TextLinkButton(title: "Got it") {
                    withAnimation { hasSeenSafetyTip = true }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DoggoSpacing.md)
        .background(DoggoColor.cardWhite, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
        .transition(.opacity)
    }

    private var bottomBar: some View {
        HStack {
            roundIconButton("chevron.left", action: onClose)

            Spacer()

            Button(action: handleShutter) {
                Circle()
                    .fill(.white)
                    .frame(width: 68, height: 68)
                    .overlay(Circle().stroke(DoggoColor.ink, lineWidth: 3).padding(4))
                    .opacity(viewModel.isCapturing ? 0.6 : 1)
            }
            .buttonStyle(ScalePressButtonStyle())
            .disabled(viewModel.isCapturing)

            Spacer()

            roundIconButton("ellipsis", action: {})
        }
    }

    private func roundIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    private func handleShutter() {
        Task {
            if let dog = await viewModel.attemptCatch(in: modelContext) {
                onCaught(dog)
            } else {
                withAnimation { showMissBanner = true }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation { showMissBanner = false }
            }
        }
    }
}
