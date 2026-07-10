# DoggoCollector — Breed Classifier Training

Trains a Core ML dog-breed classifier on the [Stanford Dogs dataset](http://vision.stanford.edu/aditya86/ImageNetDogs/) (Khosla, Jayadevaprakash, Yao, Fei-Fei — 120 breeds) via the scriptable `CreateML` framework, and exports the trained model straight into the app's source tree.

## Running it

```bash
cd training
swift train_breed_classifier.swift
```

Plain `swift` — not the Create ML GUI app (not automatable). No `DEVELOPER_DIR` override needed for the script itself, though having the Xcode-beta one set is harmless. If you hit the `CVPixelBufferPool` issue described below, compile and run the binary instead (`swiftc -O train_breed_classifier.swift -o train_breed_classifier_bin && ./train_breed_classifier_bin`) — same behavior either way, but useful for iterating faster on a smaller test.

The script is staged and idempotent — each stage is skipped if its output already exists:

1. Disk check (aborts if < 3 GB free)
2. Download `images.tar` (~757 MB) into `data/`
3. Extract, then **delete the tar immediately** (disk-space discipline)
4. Prepare: clean breed labels ("n02106662-German_shepherd" → "German Shepherd"), deterministic 80/20 split per class into `data/prepared/train` and `data/prepared/test` (files are **moved**, not copied)
5. **Cap each class at 48 train / 12 test images** — see "Why capped at 60/class" below
6. Train an `MLImageClassifier` (default `.scenePrint(revision: 1)` feature extractor — the exported model stores only the classifier head, so it stays small)
7. Evaluate on the held-out `test/` split, write `report.md` with accuracy + the worst confusion pairs
8. Export to `../DoggoCollector/Core/Detection/BreedClassifier.mlmodel` (see "Why `.mlmodel`, not `.mlpackage`" below) — Xcode's synchronized-group support picks this up automatically, no pbxproj edit needed

The script prints stage progress as it goes.

**The script never gates on accuracy** — it reports the numbers in `report.md` and lets a human judge whether they're good enough.

## Why capped at 60 images/class (deviation from the original plan)

The plan assumed training on the full dataset (~16.4k train images). On the Mac this was built on, `MLImageClassifier`'s scenePrint feature extraction reliably throws `Vision.VisionError.internalError("Failed to create CVPixelBufferPool.")` somewhere in the ~7,200–12,000 image range — confirmed via live bisection (2,400 and 7,200 images both trained fine in isolated tests; 12,000 and the full ~16,400 both failed the same way, three times, both interpreted via `swift` and as a compiled binary — ruling out JIT-vs-compiled as the cause). Root cause not pinned down further — not class-count-related (120 classes at low per-class counts works fine), looks like a session-specific GPU/Vision resource ceiling rather than something fixable from user code. 60 images/class (~48 train / 12 test after the split) was the largest confirmed-working tier tried; the resulting model trained to 95% training accuracy / ~53% validation / 55% test accuracy on the held-out set for full 120-way fine-grained classification — a real, well-above-chance signal (chance is <1% for 120 classes), just not a highly precise one given the reduced per-class sample. If you have a Mac where the full dataset trains without this error, raise or remove the cap in the script's "Per-class cap" section — nothing else about the pipeline depends on the specific number.

## Why `.mlmodel`, not `.mlpackage`

The original plan assumed `classifier.write(to:metadata:)` would produce a `.mlpackage`. On the installed CreateML SDK it actually writes a single `.mlmodel` file — and if given a destination path with a different extension, it silently *appends* `.mlmodel` rather than erroring (verified live: naming the destination `BreedClassifier.mlpackage` produced `BreedClassifier.mlpackage.mlmodel` on disk). The script now targets `.mlmodel` directly. Functionally equivalent for Xcode's purposes either way — both formats are picked up by the synchronized group and generate the same `BreedClassifier` Swift class.

## Adding `mixed_or_uncertain` photos

The 120 Stanford Dogs classes don't include a "mixed-breed street dog" class, but `CoreMLBreedClassifier`'s confidence threshold (0.65, in the app) already treats any low-confidence result as `mixed_or_uncertain` ("Indie mix" in the UI) — so the 120-class model is useful as-is.

If you want a real 121st class instead of relying purely on the threshold:

1. `mkdir -p data/prepared/train/mixed_or_uncertain data/prepared/test/mixed_or_uncertain`, then drop street-dog photos into each (roughly 80/20 split by hand is fine). The per-class cap applies here too — no more than ~48/12 will actually be used even if you add more.
2. Delete `DoggoCollector/Core/Detection/BreedClassifier.mlmodel` (the script skips training if it already exists).
3. Re-run `swift train_breed_classifier.swift` — it detects the non-empty `mixed_or_uncertain/` folder and trains a 121-class model automatically. No code changes anywhere else are needed; `CoreMLBreedClassifier` just gets a real model file with a `mixed_or_uncertain` class now included among the top-1 candidates, on top of (not instead of) the existing confidence-threshold fallback.

## Licensing

**Never commit or bundle the Stanford Dogs images** — only the trained model file ships in the app. `data/` is gitignored at the repo root (`training/data/`, plus `*.tar`) specifically so this can't happen by accident. The dataset's own terms restrict it to non-commercial research use; training a model from it and shipping the resulting model weights (not the images themselves) is the standard, accepted use of ImageNet-derived datasets like this one — but the raw photos themselves must never end up in version control or the app bundle.
