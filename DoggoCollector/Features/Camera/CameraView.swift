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
    @AppStorage("livePhotoCaptureEnabled") private var livePhotoEnabled = true
    /// The zoom factor a pinch gesture is scaling from — captured lazily on
    /// the first `.onChanged` of each gesture (whatever the live factor is
    /// at that moment, regardless of whether it got there via a previous
    /// pinch or a chip tap) and cleared on `.onEnded` so the next gesture
    /// re-captures fresh. Keeps the gesture code itself "dumb" (per the
    /// plan) — no manual re-syncing needed from other zoom-changing sites.
    @State private var pinchGestureBaseFactor: CGFloat?

    var body: some View {
        ZStack {
            Group {
                if viewModel.cameraService.isAuthorized {
                    CameraPreviewView(session: viewModel.cameraService.session)
                } else {
                    Color.black
                }
            }
            .opacity(viewModel.isCapturing ? 0.7 : 1)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isCapturing)

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

                    if viewModel.isCapturing {
                        HStack(spacing: DoggoSpacing.sm) {
                            Text("Scout's checking\u{2026}")
                                .font(DoggoTextStyle.bodySemibold)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                            BouncingDotsView()
                        }
                        .transition(.opacity)
                    } else {
                        Text(showMissBanner ? "No dog spotted — try again!" : "Point at a doggo")
                            .font(DoggoTextStyle.bodySemibold)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isCapturing)

                Spacer()

                zoomChips

                if !hasSeenSafetyTip {
                    safetyTipCard
                }

                bottomBar
            }
            .padding(.horizontal, DoggoSpacing.lg)
            .padding(.top, DoggoSpacing.lg)
            .padding(.bottom, DoggoSpacing.xl)
        }
        // Attaches to the whole panel, including buttons — safe, since
        // magnification needs two simultaneous touches and buttons win
        // over a two-finger gesture by default.
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    guard !viewModel.isCapturing else { return }
                    let base = pinchGestureBaseFactor ?? viewModel.cameraService.currentZoomFactor
                    if pinchGestureBaseFactor == nil { pinchGestureBaseFactor = base }
                    viewModel.cameraService.setZoomFactor(base * value.magnification, animated: false)
                }
                .onEnded { _ in
                    pinchGestureBaseFactor = nil
                }
        )
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            // Hidden entirely on unsupported hardware/Simulator — there's
            // nothing useful to toggle there (see CameraService's
            // isLivePhotoCaptureSupported).
            if viewModel.cameraService.isLivePhotoCaptureSupported {
                Button {
                    livePhotoEnabled.toggle()
                } label: {
                    Image(systemName: livePhotoEnabled ? "livephoto" : "livephoto.slash")
                        .foregroundStyle(livePhotoEnabled ? DoggoColor.marigold : .white)
                        .glassCircleChrome(size: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Hidden when there's no camera (Simulator), only one zoom anchor
    /// exists (nothing to pick between), or the one-time safety tip is
    /// still showing — the tip already competes for the same vertical
    /// budget the panel's fixed height was tuned around (decision #12),
    /// so this trades a moment of chip unavailability for guaranteed
    /// no-clip rather than trying to shrink anything the morph depends on.
    @ViewBuilder
    private var zoomChips: some View {
        if hasSeenSafetyTip,
           viewModel.cameraService.hasCameraInput,
           let context = viewModel.cameraService.zoomContext,
           context.anchorFactors.count > 1 {
            HStack(spacing: DoggoSpacing.sm) {
                ForEach(context.anchorFactors, id: \.self) { anchor in
                    zoomChip(anchor: anchor, context: context)
                }
            }
        }
    }

    private func zoomChip(anchor: CGFloat, context: ZoomContext) -> some View {
        let selected = nearestAnchor(to: viewModel.cameraService.currentZoomFactor, in: context.anchorFactors) == anchor
        let label = Text(formattedZoomLabel(context.displayValue(for: anchor)))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(width: 32, height: 32)
        return Button {
            guard !viewModel.isCapturing else { return }
            viewModel.cameraService.setZoomFactor(anchor, animated: true)
        } label: {
            if selected {
                label.foregroundStyle(DoggoColor.ink).background(.white, in: Circle())
            } else {
                label.foregroundStyle(.white).glassCircleChrome(size: 32)
            }
        }
        .buttonStyle(.plain)
    }

    private func nearestAnchor(to factor: CGFloat, in anchors: [CGFloat]) -> CGFloat? {
        anchors.min { abs($0 - factor) < abs($1 - factor) }
    }

    /// Apple-style zoom labels: sub-1x anchors show a bare decimal
    /// ("0.5"), integer-ish values show "1x"/"2x"/"3x", anything else
    /// (only reachable mid-pinch, not by a fixed chip anchor) falls back
    /// to one decimal place.
    private func formattedZoomLabel(_ value: CGFloat) -> String {
        if value < 1 {
            return String(format: "%.1f", value)
        }
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded()))x"
        }
        return String(format: "%.1fx", value)
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
        .glassEffect(.regular, in: .rect(cornerRadius: DoggoRadius.control))
        .transition(.opacity)
    }

    private var bottomBar: some View {
        GlassEffectContainer {
            HStack {
                roundIconButton("chevron.left", action: onClose)

                Spacer()

                // Deliberately NOT glassed — a camera shutter's affordance is
                // its solidity (Apple's own Camera app keeps a solid shutter
                // in the glass era). Glassing the single most important
                // control here would read as decoration.
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

                roundIconButton("speaker.wave.2.fill", action: viewModel.replayWhistle)
            }
        }
    }

    private func roundIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.white)
                .glassCircleChrome(size: 44)
        }
        .buttonStyle(.plain)
    }

    private func handleShutter() {
        Task {
            if let dog = await viewModel.attemptCatch(in: modelContext, liveMovie: livePhotoEnabled) {
                onCaught(dog)
            } else {
                withAnimation { showMissBanner = true }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation { showMissBanner = false }
            }
        }
    }
}
