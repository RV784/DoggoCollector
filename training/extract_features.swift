#!/usr/bin/env swift
//
//  extract_features.swift
//  Stage A of the "extract features separately from training" fix for the
//  CVPixelBufferPool crash (see CLAUDE.md Known Issue #16).
//
//  MLImageClassifier(trainingData:parameters:) does its own internal bulk
//  scenePrint feature extraction over the whole training set in one
//  continuous call, and that's exactly where this Mac reliably crashes with
//  `Vision.VisionError.internalError("Failed to create CVPixelBufferPool.")`
//  somewhere between 7,200 and 16,418 images — confirmed to still happen
//  even with Xcode/Simulator closed and after a full reboot, ruling out
//  simple resource contention. An Apple staff member hit the same wall on a
//  different large dataset (Apple Developer Forums thread #749005) and
//  recommended exactly this: extract features one image at a time via the
//  lower-level CreateMLComponents.ImageFeaturePrint, write them to disk, and
//  train the classifier head from the cached features instead of raw images.
//
//  This script does the extraction half, one image at a time (no batching,
//  no concurrency) instead of one giant internal bulk call. Critically it's
//  resumable: each image's feature vector is written to its own file, and
//  already-extracted images are skipped on re-run — so if this still
//  crashes partway through, nothing is lost, and re-running the same
//  command just picks up where it left off. Run it in a retry loop:
//
//    until ./extract_features_bin; do echo "restarting..."; done
//
//  Usage: swift extract_features.swift  (or compile: swiftc -O extract_features.swift -o extract_features_bin)
//

import CreateMLComponents
import CoreML
import CoreImage
import Foundation

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let dataDir = scriptDir.appendingPathComponent("data")
let preparedDir = dataDir.appendingPathComponent("prepared")
let featuresDir = dataDir.appendingPathComponent("features")

func log(_ message: String) {
    print("[extract_features] \(message)")
    fflush(stdout)
}

func featureFileURL(for imageURL: URL, split: String, className: String) -> URL {
    featuresDir
        .appendingPathComponent(split)
        .appendingPathComponent(className)
        .appendingPathComponent(imageURL.deletingPathExtension().lastPathComponent + ".f32")
}

// Simple binary format: [Int32 dimensionCount][Int32 x dimensionCount shape][Float32 x count scalars]
func writeFeature(_ feature: MLShapedArray<Float>, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var data = Data()
    let shape = feature.shape
    var dimCount = Int32(shape.count)
    withUnsafeBytes(of: &dimCount) { data.append(contentsOf: $0) }
    for dim in shape {
        var d = Int32(dim)
        withUnsafeBytes(of: &d) { data.append(contentsOf: $0) }
    }
    feature.withUnsafeShapedBufferPointer { ptr, _, _ in
        data.append(contentsOf: UnsafeRawBufferPointer(ptr))
    }
    try data.write(to: url, options: .atomic)
}

let extractor = ImageFeaturePrint()
let reader = ImageReader()

func collectImages(split: String) throws -> [(url: URL, className: String)] {
    let splitDir = preparedDir.appendingPathComponent(split)
    guard fileManager.fileExists(atPath: splitDir.path) else { return [] }
    let classDirs = try fileManager.contentsOfDirectory(at: splitDir, includingPropertiesForKeys: nil)
        .filter { $0.hasDirectoryPath }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    var result: [(url: URL, className: String)] = []
    for classDir in classDirs {
        let className = classDir.lastPathComponent
        let files = try fileManager.contentsOfDirectory(at: classDir, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            result.append((file, className))
        }
    }
    return result
}

func run() async throws {
    for split in ["train", "test"] {
        let images = try collectImages(split: split)
        log("\(split): \(images.count) source images")
        var extracted = 0
        var skipped = 0
        var failed = 0
        for (index, entry) in images.enumerated() {
            let outURL = featureFileURL(for: entry.url, split: split, className: entry.className)
            if fileManager.fileExists(atPath: outURL.path) {
                skipped += 1
                continue
            }
            do {
                let ciImage = try reader.applied(to: entry.url)
                let feature = try await extractor.applied(to: ciImage, eventHandler: nil)
                try writeFeature(feature, to: outURL)
                extracted += 1
            } catch {
                failed += 1
                log("  \u{26A0}\u{FE0F}  failed on \(entry.url.lastPathComponent): \(error)")
            }
            if (index + 1) % 200 == 0 {
                log("  \(split): \(index + 1)/\(images.count) processed (\(extracted) extracted this run, \(skipped) already done, \(failed) failed)")
            }
        }
        log("\(split) complete: \(extracted) extracted, \(skipped) already done, \(failed) failed")
    }
    log("ALL DONE")
}

// Single top-level async bridge for the whole script (not one per image) —
// avoids nesting semaphore-blocked Tasks inside Swift's cooperative thread
// pool thousands of times, which risks starving it.
let doneSemaphore = DispatchSemaphore(value: 0)
var topLevelError: Error?
Task {
    do {
        try await run()
    } catch {
        topLevelError = error
    }
    doneSemaphore.signal()
}
doneSemaphore.wait()
if let topLevelError {
    throw topLevelError
}
