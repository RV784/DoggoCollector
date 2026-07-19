//
//  LivePhotoMovieProcessor.swift
//  DoggoCollector
//
//  Transcodes a raw AVCapture live-photo movie (sensor-ish resolution,
//  ~2-4MB for ~3s) into a square, downscaled, silent HEVC .mov matching
//  croppedToSquare()'s crop exactly, so the still and its moving companion
//  frame identically wherever they're shown together — ~0.7-1.0MB per
//  catch instead of storing the raw capture verbatim. A live-photo movie
//  is presentation-only enrichment (the catch is already saved by the time
//  this runs, see CameraViewModel's deferred-patch task): every failure
//  path here returns nil rather than throwing, so a transcode hiccup never
//  costs the user their catch, just its moving-photo companion.
//
//  Uses the classic AVAssetReader/AVAssetWriter callback-based API, which
//  this iOS 27 SDK deprecates in favor of a new async surface
//  (AVAssetReader.outputProvider, AVAssetWriter.inputReceiver,
//  SampleBufferReceiver.append) — checked, and that surface isn't declared
//  in this SDK's Objective-C headers or exposed via any .swiftinterface
//  found on this machine, only named in the old API's deprecation
//  messages, so its real signatures aren't verifiable here. Given that and
//  no way to test this transcoder end-to-end in this environment (no real
//  captured movie file to feed it — camera-only, device-only, same as
//  every other capture-timing claim in this app), staying on the classic,
//  verified-correct API is the safer call than rewriting blind against an
//  undocumented one. Same "deprecated but functional, migration out of
//  scope for now" posture as CLGeocoder elsewhere in this app.
//

import AVFoundation
import CoreMedia

enum LivePhotoMovieProcessor {
    /// Output resolution/bitrate presets. `.tile` exists specifically for
    /// the Pack grid — added after real on-device use showed grid tiles
    /// paying the same 720x720/2.5Mbps decode cost as a full-size card
    /// despite rendering at a fraction of the size. Bitrate is scaled down
    /// roughly with pixel count (360² is 1/4 of 720²) rather than picked
    /// independently, since compression quality scales with resolution.
    enum Tier {
        case full
        case tile

        var outputSide: CGFloat {
            switch self {
            case .full: 720
            case .tile: 360
            }
        }

        var bitrate: Int {
            switch self {
            case .full: 2_500_000
            case .tile: 800_000
            }
        }
    }

    static func transcodeSquare(input: URL, photoDisplayTime: CMTime, assetIdentifier: String, tier: Tier = .full) async -> Data? {
        do {
            return try await transcodeSquareThrowing(input: input, assetIdentifier: assetIdentifier, tier: tier)
        } catch {
            // TEMP diagnostics (live-photo regression hunt, 2026-07-17)
            print("[LivePhoto] transcode(\(tier)) failed: \(error)")
            return nil
        }
    }

    private static func transcodeSquareThrowing(input: URL, assetIdentifier: String, tier: Tier) async throws -> Data {
        let outputSide = tier.outputSide
        let bitrate = tier.bitrate
        let asset = AVURLAsset(url: input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw TranscodeError.noVideoTrack
        }
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await track.load(.nominalFrameRate)

        // Capture movies are transform-rotated, not pixel-rotated — the
        // raw naturalSize is pre-transform, so it alone would be wrong for
        // a portrait capture. This is the same reasoning croppedToSquare()
        // applies to the still via imageOrientation.
        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let orientedSize = CGSize(width: abs(orientedRect.width), height: abs(orientedRect.height))
        guard orientedSize.width > 0, orientedSize.height > 0 else {
            throw TranscodeError.invalidGeometry
        }

        // Scale so the *shorter* oriented dimension maps to outputSide,
        // then center — the same center-crop croppedToSquare() applies to
        // the still, so the two frame identically.
        let shorterSide = min(orientedSize.width, orientedSize.height)
        let scale = outputSide / shorterSide
        let scaledSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let centerTransform = CGAffineTransform(
            translationX: (outputSide - scaledSize.width) / 2,
            y: (outputSide - scaledSize.height) / 2
        )
        let layerTransform = preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(centerTransform)

        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: outputSide, height: outputSide)
        // Copies source timing through rather than resampling to a fixed
        // rate — nominalFrameRate can report 0 in edge cases, hence the
        // fallback.
        let frameRate = nominalFrameRate > 0 ? nominalFrameRate : 30
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(layerTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [track],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        readerOutput.videoComposition = composition
        guard reader.canAdd(readerOutput) else { throw TranscodeError.cannotConfigureReader }
        reader.add(readerOutput)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        let writer = try AVAssetWriter(url: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(outputSide),
            AVVideoHeightKey: Int(outputSide),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate],
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(writerInput) else { throw TranscodeError.cannotConfigureWriter }
        writer.add(writerInput)

        // Content-identifier pairing stamp — nearly free to include, only
        // consumed by a future "save as a real Live Photo" feature (see
        // the camera-revamp plan's §9, not built in this pass). The
        // fiddlier still-image-time *timed metadata track* was dropped
        // per the plan's own pre-authorized fallback ("if this sub-step
        // fights back, ship without it") — in-app playback (AVPlayer
        // looping a plain .mov) never reads either one.
        let identifierItem = AVMutableMetadataItem()
        identifierItem.identifier = .quickTimeMetadataContentIdentifier
        identifierItem.value = assetIdentifier as NSString
        identifierItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [identifierItem]

        guard reader.startReading() else { throw TranscodeError.readerFailedToStart }
        guard writer.startWriting() else { throw TranscodeError.writerFailedToStart }
        writer.startSession(atSourceTime: .zero)

        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let queue = DispatchQueue(label: "com.doggocollector.livephoto.transcode")
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            continuation.resume(returning: writer.status == .completed)
                        }
                        return
                    }
                }
            }
        }

        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard success else { throw TranscodeError.writeFailed }
        return try Data(contentsOf: outputURL)
    }

    private enum TranscodeError: Error {
        case noVideoTrack, invalidGeometry, cannotConfigureReader, cannotConfigureWriter
        case readerFailedToStart, writerFailedToStart, writeFailed
    }
}
