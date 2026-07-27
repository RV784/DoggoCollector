//
//  GalleryPlaybackView.swift
//  DoggoCollector
//
//  Cycles a dog's whole gallery in place: a live photo plays its movie
//  through, a plain photo holds for a beat with a slow zoom, and the view
//  crossfades on to the next one — looping forever while it's on screen.
//
//  Replaces the movie-only LoopingMovieView on cards. That one could only
//  show photos that HAD movies, so a gallery mixing live and plain photos
//  silently skipped every plain one; and its queue-recycling loop stalled on
//  a single-movie gallery, because AVQueuePlayer had already dropped the
//  finished item from `items()` by the time the end notification arrived, so
//  the "is this mine?" guard rejected it and nothing was ever re-enqueued.
//
//  Duration-driven rather than notification-driven: the movie's own duration
//  is read up front and simply slept through. That can't hang the way an
//  end-notification that never arrives can (a failed/missing movie just
//  advances on schedule), and it makes a one-slide gallery loop for free —
//  the run loop comes back around and replays it.
//

import SwiftUI
import AVFoundation

/// One step in a dog's gallery playback. Still slides carry undecoded `Data`
/// (cheap to pass — it's only decoded, via PhotoDecoder's cache, while it's
/// actually the visible slide, so a 200-photo gallery never decodes 200
/// images).
struct GallerySlide: Identifiable, Equatable {
    let id: String
    let movieURL: URL?
    let imageData: Data?

    var isMovie: Bool { movieURL != nil }
}

struct GalleryPlaybackView: View {
    let slides: [GallerySlide]
    /// Decode budget for still slides — `.tile` on grid cards, `.card` on the
    /// hero, matching how PhotoDecoder is used everywhere else.
    var decodeSize: PhotoDecoder.Size = .tile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var zoomedIn = false
    /// One reused player for the whole sequence — `replaceCurrentItem` per
    /// movie slide rather than a fresh AVPlayer each time, so a grid of
    /// cycling cards isn't churning player objects every few seconds.
    @State private var player = AVPlayer()
    @State private var isShowingMovie = false

    /// How long a plain photo holds. Long enough to read as "resting on this
    /// photo", short enough that a gallery still feels like it's moving.
    private let stillHold: Double = 2.8
    private let crossfade: Double = 0.45

    private var current: GallerySlide? {
        slides.indices.contains(index) ? slides[index] : nil
    }

    var body: some View {
        ZStack {
            if let current, let data = current.imageData,
               let image = PhotoDecoder.image(from: data, size: decodeSize, cacheKey: current.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // The slow zoom. Driven off the slide id so each new
                    // still starts from 1.0 again instead of inheriting the
                    // previous slide's scale.
                    .scaleEffect(zoomedIn && !reduceMotion ? 1.09 : 1.0)
                    .id(current.id)
                    .transition(.opacity)
            }

            // Kept mounted (not conditionally inserted) so switching between
            // movie slides never re-creates the layer — only its opacity
            // changes.
            PlayerLayerView(player: player)
                .opacity(isShowingMovie ? 1 : 0)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: crossfade), value: index)
        .task(id: slides) { await run() }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    private func run() async {
        guard !slides.isEmpty else { return }
        player.isMuted = true
        index = 0

        // A lone plain photo has nothing to cycle and shouldn't pulse on a
        // loop — show it and stop (also the Reduce Motion shape for it).
        if slides.count == 1 && !slides[0].isMovie {
            isShowingMovie = false
            return
        }

        while !Task.isCancelled {
            guard slides.indices.contains(index) else { return }
            let slide = slides[index]

            if let url = slide.movieURL {
                isShowingMovie = true
                await playThrough(url)
            } else {
                isShowingMovie = false
                zoomedIn = false
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: stillHold + crossfade)) { zoomedIn = true }
                }
                try? await Task.sleep(for: .seconds(stillHold))
            }

            guard !Task.isCancelled else { return }
            // One slide: loop it in place rather than advancing to itself,
            // which would fire a pointless crossfade.
            guard slides.count > 1 else { continue }
            index = (index + 1) % slides.count
        }
    }

    /// Plays `url` once and returns when it's done — by its own duration, so
    /// a movie that fails to load costs one short beat instead of stalling
    /// the whole sequence.
    private func playThrough(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration).seconds) ?? 3
        let runtime = seconds.isFinite && seconds > 0.1 ? seconds : 3
        guard !Task.isCancelled else { return }
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        await player.seek(to: .zero)
        player.play()
        try? await Task.sleep(for: .seconds(runtime))
        player.pause()
    }
}

/// Thin AVPlayerLayer host — same shape as CameraPreviewView, the app's other
/// layer-backed representable.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
