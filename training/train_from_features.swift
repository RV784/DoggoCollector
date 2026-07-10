#!/usr/bin/env swift
//
//  train_from_features.swift
//  Stage B of the "extract features separately from training" fix for the
//  CVPixelBufferPool crash (see CLAUDE.md Known Issue #16 and
//  extract_features.swift). Reads the feature vectors extract_features.swift
//  already cached to disk (no Vision/image work happens here at all, so
//  there's nothing left that could hit the same crash), fits a
//  LogisticRegressionClassifier directly on them — the same classifier head
//  MLImageClassifier uses by default — then composes it back onto
//  ImageFeaturePrint so the exported model still takes a raw image as input
//  and needs zero changes in CoreMLBreedClassifier.swift.
//
//  Usage: swift train_from_features.swift (or compile: swiftc -O train_from_features.swift -o train_from_features_bin)
//

import CreateMLComponents
import CoreML
import Foundation

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let featuresDir = scriptDir.appendingPathComponent("data/features")
let appDetectionDir = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("DoggoCollector/Core/Detection")
let modelOutputPath = appDetectionDir.appendingPathComponent("BreedClassifier.mlmodel")
let reportPath = scriptDir.appendingPathComponent("report.md")

func log(_ message: String) {
    print("[train_from_features] \(message)")
    fflush(stdout)
}

func readFeature(at url: URL) throws -> MLShapedArray<Float> {
    let data = try Data(contentsOf: url)
    let dimCount = Int(data.withUnsafeBytes { $0.load(as: Int32.self) })
    var shape: [Int] = []
    for i in 0..<dimCount {
        let offset = 4 + i * 4
        let d = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self) }
        shape.append(Int(d))
    }
    let headerSize = 4 + dimCount * 4
    let floatData = data.subdata(in: headerSize..<data.count)
    return MLShapedArray<Float>(data: floatData, shape: shape)
}

func loadSplit(_ split: String) throws -> [AnnotatedFeature<MLShapedArray<Float>, String>] {
    let splitDir = featuresDir.appendingPathComponent(split)
    let classDirs = try fileManager.contentsOfDirectory(at: splitDir, includingPropertiesForKeys: nil)
        .filter { $0.hasDirectoryPath }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    var samples: [AnnotatedFeature<MLShapedArray<Float>, String>] = []
    for classDir in classDirs {
        let label = classDir.lastPathComponent
        let files = try fileManager.contentsOfDirectory(at: classDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "f32" }
        for file in files {
            let feature = try readFeature(at: file)
            samples.append(AnnotatedFeature(feature: feature, annotation: label))
        }
    }
    return samples
}

func run() async throws {
    log("loading cached features from \(featuresDir.path)...")
    let trainSamples = try loadSplit("train")
    let testSamples = try loadSplit("test")
    log("  train: \(trainSamples.count) feature vectors, test: \(testSamples.count) feature vectors")

    let labels = Set(trainSamples.map(\.annotation))
    log("  \(labels.count) classes")

    log("fitting LogisticRegressionClassifier on cached features (no Vision/image work — should not hit the CVPixelBufferPool ceiling)...")
    let estimator = LogisticRegressionClassifier<Float, String>(labels: labels)
    let fittedModel = try await estimator.fitted(to: trainSamples)
    log("  fit complete.")

    log("evaluating on held-out test set...")
    var correct = 0
    var confusion: [String: [String: Int]] = [:]
    for sample in testSamples {
        let distribution = try await fittedModel.applied(to: sample.feature)
        let predicted = distribution.mostLikelyLabel ?? "?"
        if predicted == sample.annotation {
            correct += 1
        }
        confusion[sample.annotation, default: [:]][predicted, default: 0] += 1
    }
    let accuracy = testSamples.isEmpty ? 0.0 : Double(correct) / Double(testSamples.count)
    log("  test accuracy: \(String(format: "%.2f%%", accuracy * 100)) (\(correct)/\(testSamples.count))")

    var trainCorrect = 0
    for sample in trainSamples {
        let distribution = try await fittedModel.applied(to: sample.feature)
        if distribution.mostLikelyLabel == sample.annotation {
            trainCorrect += 1
        }
    }
    let trainAccuracy = trainSamples.isEmpty ? 0.0 : Double(trainCorrect) / Double(trainSamples.count)
    log("  training accuracy: \(String(format: "%.2f%%", trainAccuracy * 100))")

    struct ConfusionPair { let trueLabel: String; let predictedLabel: String; let count: Int }
    var pairs: [ConfusionPair] = []
    for (trueLabel, predictions) in confusion {
        for (predictedLabel, count) in predictions where predictedLabel != trueLabel {
            pairs.append(ConfusionPair(trueLabel: trueLabel, predictedLabel: predictedLabel, count: count))
        }
    }
    let worstPairs = pairs.sorted { $0.count > $1.count }.prefix(15)

    log("composing ImageFeaturePrint + fitted classifier into one exportable image-in pipeline...")
    let combined = ImageFeaturePrint().appending(fittedModel)

    try fileManager.createDirectory(at: appDetectionDir, withIntermediateDirectories: true)
    let metadata = ModelMetadata(
        description: "Dog breed classifier trained on the full Stanford Dogs set (Khosla et al.) via CreateMLComponents (ImageFeaturePrint + LogisticRegressionClassifier), features extracted one image at a time to work around a CVPixelBufferPool crash in MLImageClassifier's bulk extraction path.",
        version: "2.0",
        author: "DoggoCollector training pipeline"
    )
    try combined.export(to: modelOutputPath, metadata: metadata)
    log("exported to \(modelOutputPath.path)")

    var report = """
    # Breed Classifier Training Report (full dataset, via CreateMLComponents)

    Date: \(Date())
    Class count: \(labels.count)
    Train samples: \(trainSamples.count)
    Test samples: \(testSamples.count)
    Pipeline: CreateMLComponents.ImageFeaturePrint -> LogisticRegressionClassifier (features extracted one image at a time to work around the CVPixelBufferPool crash in MLImageClassifier's bulk extraction — see CLAUDE.md Known Issue #16)

    ## Accuracy
    - Training: \(String(format: "%.2f%%", trainAccuracy * 100))
    - Test (held-out): \(String(format: "%.2f%%", accuracy * 100))

    ## 15 worst confusion pairs (true -> predicted, count)

    """
    if worstPairs.isEmpty {
        report += "(none found)\n"
    } else {
        for pair in worstPairs {
            report += "- \(pair.trueLabel) -> \(pair.predictedLabel): \(pair.count)\n"
        }
    }
    try report.write(to: reportPath, atomically: true, encoding: String.Encoding.utf8)
    log("report written to \(reportPath.path)")
    log("Done.")
}

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
