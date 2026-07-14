# DoggoCollector — Drug-Name Reference Data

Backs the typeahead in `AddMedicationSheet`'s DRUG NAME field. Bundled as `DoggoCollector/Core/Reference/VetDrugNames.json`, loaded lazily by `Core/Reference/DrugNameDirectory.swift`.

**The non-negotiable line this whole feature is built around** (openFDA's own words — kept here verbatim per that guiding principle, regardless of which specific source ultimately supplied the data below): *"Do not rely on openFDA to make decisions regarding medical care. Always speak to your health provider about the risks and benefits of FDA-regulated products."* Concretely: this JSON contains **names and active ingredients only** — no dosage, no label text, no "typical dose" data of any kind. `AddMedicationSheet`'s dosage field is always free text, always user-typed, never suggested.

## Running it

```bash
cd drugreference
swift prepare_drug_names.swift
```

Staged and idempotent, same shape as `training/train_breed_classifier.swift`: re-running skips the download if `data/dm_spl_release_animal.zip` already exists, and skips extraction if `data/raw/` already exists. To force a full refresh, delete `drugreference/data/` first (see "Refreshing" below).

## The source: DailyMed, not openFDA — a real, verified deviation from the original plan

The implementation plan's own instruction was explicit: **"verify live first"** before writing the extractor, rather than trusting a guessed field path. That verification changed the actual data source, in order:

1. **openFDA's `animalandveterinary` namespace — tried first, rejected.** It contains only one dataset, `event` (adverse-event reports), no separate product/label file. Worse: every single record's `drug[].brand_name` field is redacted to the literal string `"MSK"` — confirmed by downloading and inspecting two full quarterly partitions (2020q3, 18,719 records; 2013q2, 19,605 records), both 100% masked. The nested `active_ingredients[].name` field *is* present and unmasked, but openFDA's own event data has no usable product name to pair it with.
2. **FDA's "Green Book" (`animaldrugsatfda.fda.gov`) — tried second, per the plan's own fallback order, rejected.** Its Advanced Search page does have a real feature list (Trade Names & Sponsor, Active Ingredients, etc., each with "Export to Excel/PDF"), but live inspection (both a raw HTML fetch and a real browser session) found every export link still rendering as an unresolved Angular template placeholder — `href="{{tradeSponsorExcelUrl}}"` literally, never substituted with a real URL, and no XHR/API call fired when the page loaded. The interactive app isn't currently functioning well enough to extract bulk data from, independent of anything in this project.
3. **DailyMed (NLM) — the plan's third fallback, and what's actually used.** `https://dailymed.nlm.nih.gov` publishes a bulk "ANIMAL LABELS" SPL (Structured Product Labeling) release — real, official, structured XML, no masking. This is the source in production.

## The DailyMed data itself

- Download: `https://dailymed-data.nlm.nih.gov/public-release-files/dm_spl_release_animal.zip` (~1.24 GB, found via DailyMed's "Download All Drug Labels" page → Full Releases → the periodic-updates/full-release combobox → "ANIMAL LABELS"). Contains ~3,567 individual per-product `.zip` files, each holding one HL7 SPL XML document (+ sometimes a label image).
- Each SPL document was parsed (via `Foundation.XMLParser`, no third-party dependency — shelled out to `/usr/bin/unzip -p` per inner zip to pipe the XML straight into the parser without extracting thousands of loose files) for exactly two fields, verified against real sample records before the extractor was written:
  - **`manufacturedProduct/manufacturedProduct/name`** — the proprietary/trade name (e.g. "Clavamox", "Amoxi-Tabs").
  - **`manufacturedProduct/.../asEntityWithGeneric/genericMedicine/name`** — the nonproprietary/generic name, which is a **separate schema field from strength/dosage** (that lives in its own `<quantity>` element this script never reads) — confirmed clean and dosage-free across a 40-record random sample before committing to this field over the noisier per-substance `ingredientSubstance/name` list (which frequently splits combination drugs into several entries, e.g. "PYRANTEL" + "FENBENDAZOLE" separately, and sometimes embeds lot numbers or strain codes for vaccines).
- Result: **2,368 unique name+ingredient pairs**, deduped case-insensitively on the product name (first-seen ingredient wins), sorted alphabetically, ~122 KB as JSON — comfortably under the "few-hundred-KB max" target. Real examples: `{"n": "Amoxi-Tabs", "i": "amoxicillin"}`, `{"n": "Clavamox", "i": "amoxicillin and clavulanate potassium"}`.
- A small number of entries are medical/anesthetic gases (`"Oxygen"`, `"Carbon Dioxide"`, `"Air"`) — real FDA-listed veterinary products, not extraction noise; harmless to leave in since the typeahead is suggest-only and free text always wins regardless.

## License / attribution

DailyMed content is a U.S. government work (NIH/NLM, FDA-sourced SPL data) — public domain, same status as openFDA. Retrieved 2026-07-14.

## The India caveat (unchanged from the original plan)

This is a **spelling-consistency layer, nothing more**. FDA/DailyMed-listed names are US-market veterinary drugs; a Guardian in India typing an Indian brand name will very often get zero typeahead matches. That's fully expected and by design — `DrugNameDirectory.matches(for:)` returns `[]` for no match, with no warning, no red state, no friction. Free text always wins.

## Refreshing later

DailyMed has no incremental-update API for this bulk file the way this script consumes it (there are separate monthly/weekly/daily "periodic update" zips, but this script deliberately uses only the full "ANIMAL LABELS" release for simplicity — same one-shot-not-continuously-synced posture as the openFDA-based `LiveCareDirectory`... except this data doesn't live-query at all, it's baked into the bundle). A refresh is a manual, occasional chore, by design:

1. `rm -rf drugreference/data` (reclaims ~2.5 GB — the 1.24 GB zip plus its ~1.2 GB of extracted inner zips).
2. Re-run `swift prepare_drug_names.swift`.
3. Rebuild the app — the regenerated `VetDrugNames.json` is picked up automatically by Xcode's synchronized group, no pbxproj edit needed.

## What was explicitly not built

No curated/supplemental Indian drug-name list (a natural future addition, same "second dataset" story as `training/README.md`'s `mixed_or_uncertain` note — just drop more `{"n":..., "i":...}` pairs into the output, or extend this script with a second source and merge before Stage 4's dedupe). No live API calls at runtime — this is a fully offline, bundled reference, matching the project's existing precedent (the breed classifier) of preparing data offline and shipping only the small clean output.
