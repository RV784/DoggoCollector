//
//  LoopingMovieView.swift
//  DoggoCollector
//
//  Plays a muted, silent movie in a continuous gapless loop for as long as
//  this view exists — the "moving photo" effect for live-photo catches
//  (Card Detail, Catch Celebration, and the Pack grid). Originally capped
//  at 3 loops then faded to the still, per the camera-revamp plan's
//  Decision F ("no tap-to-replay in v1... loops restart on each view
//  appearance") — changed after real on-device use showed that read as
//  "plays once, then looks dead" rather than a living photo, with no way
//  to see it move again short of scrolling the card off-screen and back.
//  Looping forever while visible sidesteps the tap-to-replay question
//  entirely (there's nothing to replay), so it doesn't reopen the
//  hit-testing risk Decision F was specifically avoiding (Resolved #1).
//
//  Uses AVPlayerLooper — the plan originally steered away from it
//  specifically because it loops forever and the old requirement was
//  "exactly 3, then stop." Now that the requirement itself is "loop
//  forever while visible," AVPlayerLooper is the *right* tool: gapless,
//  framework-native, no manual seek-on-notification bookkeeping.
//

import SwiftUI
import AVFoundation

struct LoopingMovieView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    // The URL this view was created with never changes for the lifetime
    // of a given instance (see the type doc) — nothing to reconcile here.
    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}

final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private let player = AVQueuePlayer()
    // Must be retained for as long as looping should continue — the
    // looper isn't retained by the player itself, and letting it
    // deallocate silently stops the loop.
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?

    init(url: URL) {
        super.init(frame: .zero)

        // Movies are silent anyway (no audio input in the capture
        // session), but muting explicitly also keeps AVAudioSession
        // untouched — the whistle uses AVAudioEngine and must not be
        // interrupted by an unrelated player starting up.
        player.isMuted = true
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        // Stays invisible until isReadyForDisplay flips true below — so
        // there's never a black flash while the movie loads in.
        alpha = 0

        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) { self?.alpha = 1 }
            }
        }

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Pauses, disables looping, and removes observers — a leaked
    /// AVPlayerLooper or KVO observer here is a crash class, not just a
    /// leak, since the closures capture `self` weakly but the underlying
    /// observer objects would otherwise outlive this view and keep firing
    /// into a deallocated context.
    func teardown() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        readyObservation?.invalidate()
        readyObservation = nil
    }
}
