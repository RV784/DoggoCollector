//
//  DrugNameDirectory.swift
//  DoggoCollector
//
//  Backs AddMedicationSheet's typeahead. Names and active ingredients only —
//  no dosage/label data ever ships here (see drugreference/README.md's
//  record-keeping-not-treatment-suggestion line). If VetDrugNames.json is
//  missing from the bundle, this returns [] forever, silently — the
//  typeahead just never suggests, and free text carries the whole flow.
//

import Foundation

struct DrugNameEntry: Decodable, Identifiable, Hashable {
    let name: String
    let activeIngredient: String
    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name = "n"
        case activeIngredient = "i"
    }
}

enum DrugNameDirectory {
    private static let entries: [DrugNameEntry] = loadEntries()

    private static func loadEntries() -> [DrugNameEntry] {
        guard let url = Bundle.main.url(forResource: "VetDrugNames", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DrugNameEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Case/diacritic-insensitive prefix match on name first, then
    /// word-boundary contains, ranked shortest-first. Pure Swift over the
    /// in-memory array (a few thousand entries at most) — no index needed,
    /// no debounce needed at in-memory speed.
    static func matches(for prefix: String, limit: Int = 5) -> [DrugNameEntry] {
        let query = prefix.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !query.isEmpty else { return [] }

        func folded(_ entry: DrugNameEntry) -> String {
            entry.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }

        let prefixMatches = entries.filter { folded($0).hasPrefix(query) }
        let wordBoundaryMatches = entries.filter {
            let name = folded($0)
            return !name.hasPrefix(query) && name.contains(" " + query)
        }

        return Array(
            (prefixMatches + wordBoundaryMatches)
                .sorted { $0.name.count < $1.name.count }
                .prefix(limit)
        )
    }
}
