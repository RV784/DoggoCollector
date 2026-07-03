//
//  WhistlePlayer.swift
//  DoggoCollector
//
//  Synthesizes the "get the dog's attention" whistle procedurally (two rising
//  chirps), mirroring the original design's Web Audio implementation — no
//  bundled audio asset needed.
//

import AVFoundation

final class WhistlePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer?

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffer = Self.makeChirpBuffer(format: format)
    }

    func play() {
        guard let buffer else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try engine.start()
            }
            player.stop()
            player.scheduleBuffer(buffer, at: nil)
            player.play()
        } catch {
            // A failed whistle shouldn't block the catch flow.
        }
    }

    private static func makeChirpBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let chirpDuration = 0.12
        let gapDuration = 0.06
        let totalDuration = chirpDuration * 2 + gapDuration
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        let startFreq = 1200.0
        let endFreq = 1800.0
        let samples = channelData[0]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let sample: Double
            if t < chirpDuration {
                sample = chirpSample(t: t, duration: chirpDuration, startFreq: startFreq, endFreq: endFreq)
            } else if t < chirpDuration + gapDuration {
                sample = 0
            } else if t < totalDuration {
                sample = chirpSample(t: t - chirpDuration - gapDuration, duration: chirpDuration, startFreq: startFreq, endFreq: endFreq)
            } else {
                sample = 0
            }
            samples[frame] = Float(sample)
        }
        return buffer
    }

    private static func chirpSample(t: Double, duration: Double, startFreq: Double, endFreq: Double) -> Double {
        let progress = t / duration
        let freq = startFreq + (endFreq - startFreq) * progress
        let envelope = sin(.pi * progress) // fades in and out so it doesn't click
        return sin(2 * .pi * freq * t) * envelope * 0.5
    }
}
