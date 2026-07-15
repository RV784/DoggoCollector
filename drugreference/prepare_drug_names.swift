#!/usr/bin/env swift
//
//  prepare_drug_names.swift
//  DoggoCollector drug-reference pipeline
//
//  Fetches FDA's own "Green Book" (Animal Drugs @ FDA) approved-application
//  index directly, extracts brand/proprietary name + active ingredient pairs
//  only (no dosage, no label text), and emits a small bundled JSON directly
//  into the app's source tree. Plain `swift` script, matching
//  training/train_breed_classifier.swift's pattern.
//
//  Usage: cd drugreference && swift prepare_drug_names.swift
//
//  WHY THE GREEN BOOK, NOT DAILYMED (verified live before rewriting this
//  script, not assumed): this script originally used DailyMed's bulk
//  "ANIMAL LABELS" SPL release because a 2026-07-14 live check of
//  animaldrugsatfda.fda.gov found its Advanced Search export links
//  rendering as unresolved Angular template placeholders
//  (`href="{{tradeSponsorExcelUrl}}"`). A follow-up live check the next day
//  (2026-07-15, via a real browser session driving the actual Advanced
//  Search UI) found the site fully functional — the export buttons fire a
//  real POST to `.../app/search/public/advancedSearchForExcelPdf` and
//  return the complete filtered result set as clean JSON, no auth, no CORS
//  restriction, "public" literally in the URL path.
//
//  Why this source is a better fit than DailyMed for "FDA approved animal
//  drugs" specifically: DailyMed's ~3,567-label bulk release is DailyMed's
//  own broader "veterinary labels" scope, which includes non-drug products
//  that happen to carry SPL labels (teat dips, disinfectants). The Green
//  Book is FDA CVM's own canonical index of actual NADA/ANADA/CNADA/EUA
//  *applications*, directly filterable server-side to
//  `applicationStatusCode: "A"` (Approved) — confirmed live: filtering
//  returns exactly 1,743 of 2,417 total applications, all genuinely status
//  "A" (status codes confirmed via the site's own
//  `/app/search/public/codes/application_status`: A=Approved,
//  W=Voluntary Withdrawn, G=Granted/R=Revoked are EUA-only). No XML, no
//  zip, no 1.24 GB download — a single JSON POST.
//

import Foundation

// MARK: - Paths

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let appReferenceDir = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("DoggoCollector/Core/Reference")
let outputPath = appReferenceDir.appendingPathComponent("VetDrugNames.json")

let endpoint = "https://animaldrugsatfda.fda.gov/adafda/app/search/public/advancedSearchForExcelPdf"
// Filtered server-side to Approved only ("A") — Voluntary Withdrawn and the
// EUA-only Granted/Revoked statuses are deliberately excluded, since this
// is meant to be a list of FDA-*approved* drugs, not a full historical
// application index. pageSize/pageNumber are accepted by the endpoint but
// ignored for this export call — it always returns the complete filtered
// set (confirmed live).
let requestBody = """
{"basicSearchTerm":null,"applicationNumber":null,"sponsorName":null,\
"activeIngredientName":null,"applicationStatusCode":"A","applicationStatusValue":null,\
"proprietaryName":null,"doseFormName":null,"routeName":null,"speciesName":null,\
"sortField":"applicationNumber","sortDirection":"true","pageSize":"10","pageNumber":1}
"""

// MARK: - Helpers

func log(_ message: String) {
    print("[prepare_drug_names] \(message)")
    fflush(stdout)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("[prepare_drug_names] ERROR: \(message)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Stage 1: Fetch the approved-application index

log("Stage 1/3: fetch FDA Green Book approved-application index")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
process.arguments = [
    "-s", "-X", "POST", endpoint,
    "-H", "Content-Type: application/json",
    "-d", requestBody,
]
let outPipe = Pipe()
process.standardOutput = outPipe
try? process.run()
let responseData = outPipe.fileHandleForReading.readDataToEndOfFile()
process.waitUntilExit()
guard process.terminationStatus == 0, !responseData.isEmpty else {
    fail("curl request failed or returned no data (exit status \(process.terminationStatus))")
}

struct FDARecord: Decodable {
    let applicationNumber: Int
    let applicationStatusCode: String?
    let proprietaryName: String?
    let activeIngredientName: String?
}

let records: [FDARecord]
do {
    records = try JSONDecoder().decode([FDARecord].self, from: responseData)
} catch {
    fail("failed to decode response as JSON: \(error)")
}
log("  fetched \(records.count) approved applications")
// A real external-API boundary — fail loudly rather than silently ship a
// truncated/empty bundled resource if the API's shape or filtering ever
// changes underneath this script.
guard records.count > 1000 else {
    fail("suspiciously few records (\(records.count)) — API shape may have changed, aborting rather than shipping a truncated list")
}

// MARK: - Stage 2: Transform to name+ingredient pairs

log("Stage 2/3: transform to name+ingredient pairs")

struct DrugEntry: Codable {
    let n: String
    let i: String
}

/// Splits on newlines (multi-ingredient records join active ingredients
/// this way, e.g. "Gelatin\nSodium Chloride\n"), trims each piece, drops
/// empties, and rejoins as a natural-language list.
func clean(_ raw: String?) -> String {
    (raw ?? "")
        .split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
}

// Sorted ascending by application number first so first-seen-wins dedup
// below is deterministic across re-runs.
var seen = Set<String>() // lowercased proprietary name
var entries: [DrugEntry] = []
for record in records.sorted(by: { $0.applicationNumber < $1.applicationNumber }) {
    let name = clean(record.proprietaryName)
    let ingredient = clean(record.activeIngredientName)
    guard !name.isEmpty, !ingredient.isEmpty else { continue }
    let key = name.lowercased()
    guard !seen.contains(key) else { continue }
    seen.insert(key)
    entries.append(DrugEntry(n: name, i: ingredient))
}
log("  \(entries.count) unique name+ingredient pairs after dedup")

// MARK: - Stage 3: Write bundled JSON

log("Stage 3/3: write VetDrugNames.json")
entries.sort { $0.n.localizedCaseInsensitiveCompare($1.n) == .orderedAscending }
try? fileManager.createDirectory(at: appReferenceDir, withIntermediateDirectories: true)
let jsonData = try! JSONEncoder().encode(entries)
try! jsonData.write(to: outputPath)
let sizeKB = Double(jsonData.count) / 1024
log("  wrote \(entries.count) entries (\(String(format: "%.0f", sizeKB)) KB) to \(outputPath.path)")
log("  Source: FDA Animal Drugs @ FDA (\"Green Book\") advancedSearchForExcelPdf, retrieved \(ISO8601DateFormatter().string(from: .now))")
log("  See drugreference/README.md for the full story and how to refresh this later.")
