# DoggoCollector — Drug-Name Reference Data

Backs the typeahead in `AddMedicationSheet`'s DRUG NAME field. Bundled as `DoggoCollector/Core/Reference/VetDrugNames.json`, loaded lazily by `Core/Reference/DrugNameDirectory.swift`.

**The non-negotiable line this whole feature is built around** (openFDA's own words — kept here verbatim per that guiding principle, regardless of which specific source ultimately supplied the data below): *"Do not rely on openFDA to make decisions regarding medical care. Always speak to your health provider about the risks and benefits of FDA-regulated products."* Concretely: this JSON contains **names and active ingredients only** — no dosage, no label text, no "typical dose" data of any kind. `AddMedicationSheet`'s dosage field is always free text, always user-typed, never suggested.

## Running it

```bash
cd drugreference
swift prepare_drug_names.swift
```

A single POST request plus a JSON transform — no download-to-disk step, no staging directory, nothing to skip-if-exists. Re-running is cheap and always re-fetches live.

## The source: FDA's own "Green Book," directly — a corrected finding, not the original plan

The implementation plan behind decision #17's original build had one instruction: **"verify live first"** before writing the extractor, rather than trusting a guessed field path. That verification changed the data source twice, in order:

1. **openFDA's `animalandveterinary` namespace — tried first, rejected.** It contains only one dataset, `event` (adverse-event reports), no separate product/label file. Worse: every single record's `drug[].brand_name` field is redacted to the literal string `"MSK"` — confirmed by downloading and inspecting two full quarterly partitions (2020q3, 18,719 records; 2013q2, 19,605 records), both 100% masked.
2. **FDA's "Green Book" (`animaldrugsatfda.fda.gov`) — tried second, rejected at the time (2026-07-14).** Its Advanced Search page has a real feature set (search by ingredient/sponsor/proprietary name/etc., with "Export to Excel/PDF" on the results), but live inspection that day found every export link rendering as an unresolved Angular template placeholder — `href="{{tradeSponsorExcelUrl}}"` literally, never substituted with a real URL. The interactive app wasn't functioning well enough to extract bulk data from at that time.
3. **DailyMed (NLM) — used as the fallback for a day**, until a follow-up live check (2026-07-15, this time via a real interactive browser session actually driving the Advanced Search UI end-to-end, not just a raw HTML fetch) found the Green Book fully functional: clicking "Export to Excel" fires `ng-click="exportExcel()"`, which POSTs to a real JSON API and gets back the complete result set. **This is what's actually used now** — the plan's original first choice, working as intended.

## The Green Book data itself

- Endpoint: `POST https://animaldrugsatfda.fda.gov/adafda/app/search/public/advancedSearchForExcelPdf`, `Content-Type: application/json`, body is a `searchCriteria` object with all fields nullable except `applicationStatusCode: "A"` (Approved-only — see below). No auth, no CORS restriction, "public" literally in the URL path — this is the same data a person gets by clicking through the UI, just automated. `pageSize`/`pageNumber` are accepted but ignored by this specific export endpoint; it always returns the complete filtered set (confirmed live: `pageSize:"10"` still returned all 1,743 matching records).
- Filtered server-side to `applicationStatusCode: "A"` — confirmed via the site's own `/app/search/public/codes/application_status` lookup: `A`=Approved, `W`=Voluntary Withdrawn, `G`=Granted/`R`=Revoked (both EUA-only). Of 2,417 total applications on file, 1,743 are currently Approved; this script only fetches those.
- Each record has `applicationNumber`, `applicationType` (NADA/ANADA/CNADA/EUA — confirmed via `/app/search/public/codes/application_type`), `applicationStatusCode`, `publishDate`, `proprietaryName`, `sponsorName`, `activeIngredientName`, `voluntaryWithdrawalDate`. No dosage or strength field anywhere in this payload — the "names and active ingredients only" rule above is structurally guaranteed by the source, not just by this script's own restraint.
- Multi-ingredient products (487 of the 1,743 records) list `activeIngredientName` as newline-joined pieces (e.g. `"Gelatin\nSodium Chloride\n"`) — this script splits, trims, and rejoins as `"Gelatin, Sodium Chloride"`.
- Result: **1,597 unique name+ingredient pairs**, deduped case-insensitively on the proprietary name (first-seen wins, sorted by application number ascending first so this is deterministic across re-runs), sorted alphabetically for output, ~98 KB as JSON. Real examples: `{"n": "amoxi-tabs®", "i": "Amoxicillin Trihydrate"}`, `{"n": "Rimadyl® Caplets", "i": "Carprofen"}`.
- **This is meaningfully smaller than the DailyMed-based version's 2,368 entries — a scope-precision improvement, not a regression.** DailyMed's bulk "ANIMAL LABELS" release covers all veterinary product *labels*, which includes non-drug items that happen to carry an SPL label (teat dips, disinfectants). The Green Book indexes only actual NADA/ANADA/CNADA/EUA *applications* — this is a more precise match for "FDA-approved animal drugs" specifically. One consequence worth knowing: topical parasiticides regulated by the EPA rather than FDA (e.g. Frontline/fipronil) won't appear here — that's correct scope, not a gap in this script.

## License / attribution

FDA's Animal Drugs @ FDA ("Green Book") data is a U.S. government work — public domain, same status as openFDA and DailyMed. Retrieved 2026-07-15.

## The India caveat (unchanged from the original plan)

This is a **spelling-consistency layer, nothing more**. FDA-listed names are US-market veterinary drugs; a Guardian in India typing an Indian brand name will very often get zero typeahead matches. That's fully expected and by design — `DrugNameDirectory.matches(for:)` returns `[]` for no match, with no warning, no red state, no friction. Free text always wins.

## Refreshing later

**Policy: manual, roughly monthly — a deliberate choice, checked against real data rather than assumed.** A scheduled auto-refresh (cloud agent on a cron, opening a PR on change rather than auto-merging) was considered and could be added later, but before building it the actual update cadence was investigated: the full 1,743-record Approved set was pulled and its `publishDate` distribution analyzed.

- **`publishDate` is not a clean "date of original approval."** It's dominated by huge same-day spikes consistent with batch migration/re-indexing rather than individual approvals: 514 of 1,743 records (~30%) share the single date `2016-06-01` (almost certainly a digitization/backfill date), and several other dates each account for 20-53 records. This pattern isn't just historical — the single most recent date at time of checking accounted for 19 records on its own, against a background of 0-2 records on most other days in the preceding two months. So this field tracks "last (re-)published into the index," not a stable per-record approval timestamp.
- **Filtering out those batch-spike dates, real day-to-day activity is a slow trickle** — most days show 0-2 records touched. Even without filtering anything out, a raw last-30-days count only reaches ~2% of the total list.
- **Conclusion**: monthly manual refresh is comfortably sufficient — likely more frequent than this data actually needs. There's no live-freshness reason to automate this; it stays a manual, reviewed step:

```bash
cd drugreference
swift prepare_drug_names.swift
```

Then rebuild the app — the regenerated `VetDrugNames.json` is picked up automatically by Xcode's synchronized group, no pbxproj edit needed. Review the diff (`git diff DoggoCollector/Core/Reference/VetDrugNames.json`) before committing, same as any other change.

## What was explicitly not built

No curated/supplemental Indian drug-name list (a natural future addition — just drop more `{"n":..., "i":...}` pairs into the output, or extend this script with a second source and merge before Stage 3's write). No inclusion of Voluntary Withdrawn drugs (the typeahead is for currently-administrable medications; free text still covers anything not suggested). No live API calls at runtime — this is a fully offline, bundled reference, matching the project's existing precedent (the breed classifier) of preparing data offline and shipping only the small clean output.
