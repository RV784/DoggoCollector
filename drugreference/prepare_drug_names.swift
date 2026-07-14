#!/usr/bin/env swift
//
//  prepare_drug_names.swift
//  DoggoCollector drug-reference pipeline
//
//  Downloads DailyMed's full "ANIMAL LABELS" SPL (Structured Product
//  Labeling) release, extracts brand/proprietary name + active ingredient
//  pairs only (no dosage, no label text), and emits a small bundled JSON
//  directly into the app's source tree. Plain `swift` script, staged and
//  idempotent — matching training/train_breed_classifier.swift's pattern.
//
//  Usage: cd drugreference && swift prepare_drug_names.swift
//
//  WHY DAILYMED, NOT OPENFDA'S "animalandveterinary" ENDPOINT (verified
//  live before writing this script, not assumed):
//  openFDA's animalandveterinary namespace contains only adverse-event
//  reports (`event`), and every single record's `drug[].brand_name` field
//  is redacted to the literal string "MSK" — confirmed by downloading and
//  inspecting two full quarterly partitions (2020q3 and 2013q2), both
//  100% masked. FDA's own "Green Book" product database
//  (animaldrugsatfda.fda.gov) was tried next per the plan's fallback
//  order, but its Advanced Search page's Excel/PDF export links are
//  unresolved Angular template placeholders (`{{tradeSponsorExcelUrl}}`)
//  in the live HTML — that interactive app isn't currently functioning
//  well enough to extract data from. DailyMed's bulk "ANIMAL LABELS"
//  release (dm_spl_release_animal.zip, ~1.24 GB, ~3,500 real veterinary
//  product labels) is a proper structured HL7 SPL XML export with a
//  reliable `manufacturedProduct/name` (brand) and
//  `manufacturedProduct/asEntityWithGeneric/genericMedicine/name`
//  (active ingredient, already dosage-free by schema — strength lives in
//  a separate `<quantity>` element this script never reads) — confirmed
//  by parsing real sample records before committing to this field path.
//

import Foundation

// MARK: - Paths

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let dataDir = scriptDir.appendingPathComponent("data")
let zipPath = dataDir.appendingPathComponent("dm_spl_release_animal.zip")
let rawDir = dataDir.appendingPathComponent("raw")

let appReferenceDir = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("DoggoCollector/Core/Reference")
let outputPath = appReferenceDir.appendingPathComponent("VetDrugNames.json")

let downloadURL = URL(string: "https://dailymed-data.nlm.nih.gov/public-release-files/dm_spl_release_animal.zip")!

// MARK: - Helpers

func log(_ message: String) {
    print("[prepare_drug_names] \(message)")
    fflush(stdout)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("[prepare_drug_names] ERROR: \(message)\n".data(using: .utf8)!)
    exit(1)
}

@discardableResult
func run(_ executable: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try? process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

// MARK: - Stage 1: Download

log("Stage 1/5: download DailyMed animal labels release")
if fileManager.fileExists(atPath: zipPath.path) {
    log("  already downloaded at \(zipPath.path) — skipping.")
} else {
    try? fileManager.createDirectory(at: dataDir, withIntermediateDirectories: true)
    log("  downloading from \(downloadURL.absoluteString) (~1.24 GB)...")
    let status = run("/usr/bin/curl", ["-L", "-o", zipPath.path, downloadURL.absoluteString])
    guard status == 0 else { fail("curl download failed with status \(status)") }
    log("  download complete.")
}

// MARK: - Stage 2: Extract

log("Stage 2/5: extract inner per-product zips")
if fileManager.fileExists(atPath: rawDir.path) {
    log("  already extracted at \(rawDir.path) — skipping.")
} else {
    try? fileManager.createDirectory(at: rawDir, withIntermediateDirectories: true)
    log("  unzipping \(zipPath.lastPathComponent)...")
    let status = run("/usr/bin/unzip", ["-q", zipPath.path, "-d", rawDir.path])
    guard status == 0 else { fail("unzip failed with status \(status)") }
    log("  extract complete.")
}

// MARK: - Stage 3: Parse each product's SPL XML

struct DrugEntry: Codable {
    let n: String
    let i: String
}

/// Captures exactly two fields from one SPL document: the first
/// `manufacturedProduct/name` (brand) and the first
/// `genericMedicine/name` inside it (active ingredient) — both
/// immediate-child matches via a tag stack, so a `<name><suffix>…`
/// sub-element (real SPL shape, e.g. a dosage-form suffix) never leaks
/// its text into the captured name. Stops parsing as soon as both are
/// found — there's no need to read the rest of a multi-package-size doc.
final class SPLDelegate: NSObject, XMLParserDelegate {
    private enum Capture { case brand, generic }

    private var stack: [String] = []
    private var nameBuffer = ""
    private var pendingCapture: Capture?
    private(set) var brandName: String?
    private(set) var ingredientName: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "name" {
            let parent = stack.last
            if parent == "manufacturedProduct", brandName == nil {
                pendingCapture = .brand
            } else if parent == "genericMedicine", ingredientName == nil {
                pendingCapture = .generic
            } else {
                pendingCapture = nil
            }
            nameBuffer = ""
        }
        stack.append(elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard stack.last == "name", pendingCapture != nil else { return }
        nameBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "name", let capture = pendingCapture {
            let trimmed = nameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                switch capture {
                case .brand: brandName = trimmed
                case .generic: ingredientName = trimmed
                }
            }
            pendingCapture = nil
        }
        if !stack.isEmpty { stack.removeLast() }
        if brandName != nil, ingredientName != nil {
            parser.abortParsing()
        }
    }
}

func extractEntry(fromInnerZipAt path: String) -> DrugEntry? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", path, "*.xml"]
    let outPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = Pipe()
    guard (try? process.run()) != nil else { return nil }
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard !data.isEmpty else { return nil }

    let delegate = SPLDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    parser.parse()

    guard let brand = delegate.brandName, let ingredient = delegate.ingredientName else { return nil }
    return DrugEntry(n: brand, i: ingredient)
}

/// A name is a real product/ingredient name, not a stray code — drops
/// anything with no letters at all.
func looksLikeARealName(_ text: String) -> Bool {
    text.contains { $0.isLetter }
}

log("Stage 3/5: parse SPL XML for name + active ingredient pairs")
let innerZips = (try? fileManager.contentsOfDirectory(at: rawDir.appendingPathComponent("animal"), includingPropertiesForKeys: nil))?
    .filter { $0.pathExtension == "zip" } ?? []
guard !innerZips.isEmpty else { fail("no inner product zips found under \(rawDir.path)/animal") }
log("  found \(innerZips.count) product labels")

var seen = Set<String>() // lowercased brand name, for dedupe
var entries: [DrugEntry] = []
for (index, innerZip) in innerZips.enumerated() {
    if index % 500 == 0 {
        log("  processed \(index)/\(innerZips.count)...")
    }
    guard let entry = extractEntry(fromInnerZipAt: innerZip.path) else { continue }
    let name = entry.n.trimmingCharacters(in: .whitespacesAndNewlines)
    let ingredient = entry.i.trimmingCharacters(in: .whitespacesAndNewlines)
    guard looksLikeARealName(name), looksLikeARealName(ingredient) else { continue }
    let key = name.lowercased()
    guard !seen.contains(key) else { continue }
    seen.insert(key)
    entries.append(DrugEntry(n: name, i: ingredient))
}
log("  \(entries.count) unique name+ingredient pairs extracted.")

// MARK: - Stage 4: Write bundled JSON

log("Stage 4/5: write VetDrugNames.json")
entries.sort { $0.n.localizedCaseInsensitiveCompare($1.n) == .orderedAscending }
try? fileManager.createDirectory(at: appReferenceDir, withIntermediateDirectories: true)
let encoder = JSONEncoder()
let jsonData = try! encoder.encode(entries)
try! jsonData.write(to: outputPath)
let sizeKB = Double(jsonData.count) / 1024
log("  wrote \(entries.count) entries (\(String(format: "%.0f", sizeKB)) KB) to \(outputPath.path)")

// MARK: - Stage 5: Report

log("Stage 5/5: done")
log("  Source: DailyMed ANIMAL LABELS bulk release, retrieved \(ISO8601DateFormatter().string(from: .now))")
log("  See drugreference/README.md for the full story and how to refresh this later.")
