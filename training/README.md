# DoggoCollector — Breed Classifier Training

Trains a Core ML dog-breed classifier on the [Stanford Dogs dataset](http://vision.stanford.edu/aditya86/ImageNetDogs/) (Khosla, Jayadevaprakash, Yao, Fei-Fei — 120 breeds), and exports the trained model straight into the app's source tree.

## Running it (current pipeline — trains on the full dataset)

`MLImageClassifier`'s own bulk feature extraction crashes on this dataset at full scale (see "The CVPixelBufferPool crash" below), so training is now a two-stage pipeline that extracts features one image at a time instead:

```bash
cd training
swift train_breed_classifier.swift   # stages 1-4 only now: download, extract, split (no cap — see below)
swift extract_features.swift         # Stage A: per-image feature extraction, resumable, writes data/features/
swift train_from_features.swift      # Stage B: fits the classifier head on cached features, exports the model
```

(Or compile each for speed: `swiftc -O <name>.swift -o <name>_bin && ./<name>_bin` — all three behave identically either way.)

If `extract_features.swift` ever does crash partway through, just re-run it — it skips any image whose feature file already exists, so nothing already extracted is lost. To be extra safe, run it in a retry loop: `until ./extract_features_bin; do echo restarting; done`.

`train_breed_classifier.swift` still does its own stages 1-4 (download `images.tar`, extract, clean labels, deterministic 80/20 split into `data/prepared/train` and `data/prepared/test`) — run it first to populate `data/prepared/`. **It no longer caps per-class counts** (the cap was removed once the real fix below existed) — if you run its stage 5+ directly on the full set, it will still hit the crash, since that's the old bulk `MLImageClassifier` path; use `extract_features.swift` + `train_from_features.swift` instead for anything beyond a quick small-scale check.

**Nothing gates on accuracy** — `train_from_features.swift` reports the numbers in `report.md` and lets a human judge whether they're good enough.

## The CVPixelBufferPool crash, and the real fix

`MLImageClassifier(trainingData:parameters:)` does its own internal bulk scenePrint feature extraction over the whole training set in one continuous call. On this Mac, that reliably throws `Vision.VisionError.internalError("Failed to create CVPixelBufferPool.")` somewhere between ~7,200 and 16,418 images — confirmed via live bisection across multiple sessions (2,400 and 7,200 both trained fine in isolation; 12,000 and the full ~16,418 failed identically every time, 4 attempts total, including after closing Xcode/Simulator entirely and after a full reboot — ruling out both IDE resource contention and session-specific state as the cause). This is a known, unresolved issue in `MLImageClassifier` itself, not specific to this Mac or this dataset — see [Apple Developer Forums thread #767674](https://developer.apple.com/forums/thread/767674) (same exact error, large dataset, no official fix) and [thread #749005](https://developer.apple.com/forums/thread/749005) (a different large dataset, same crash pattern, Apple staff recommending exactly the fix below).

**The fix**: extract scenePrint features separately from training, one image at a time, via the lower-level `CreateMLComponents.ImageFeaturePrint` (rather than `MLImageClassifier`'s opaque bulk path), write each feature vector to its own file under `data/features/`, then fit a `CreateMLComponents.LogisticRegressionClassifier` directly on the cached feature vectors (no Vision/image work at all at that point — the same classifier head `MLImageClassifier` uses by default). The fitted classifier is composed back onto `ImageFeaturePrint` (`ImageFeaturePrint().appending(fittedModel)`) before export, so the final `.mlmodel` still takes a raw image as input and works with `CoreMLBreedClassifier.swift`/`VNCoreMLRequest` completely unchanged — verified directly against the exported model (loaded via `MLModel`+`VNCoreMLModel`, produces proper `VNClassificationObservation` results, not raw feature output).

This fully resolved the crash: the full 20,580-image set (16,418 train + 4,162 test) extracted with **zero failures**, and the resulting model reached **67.04% test accuracy / 80.10% training accuracy** — a real improvement over the old 60-images/class-capped model's 55.97% test accuracy, since this one actually sees the whole dataset. If a future session wants to push accuracy further (e.g. trying `FullyConnectedNetworkClassifier` instead of `LogisticRegressionClassifier` as the head, since features are already cached and reusable), see `train_from_features.swift` — swapping the classifier there doesn't require re-running extraction at all.

## Why `.mlmodel`, not `.mlpackage`

The original plan assumed `classifier.write(to:metadata:)` would produce a `.mlpackage`. On the installed CreateML SDK it actually writes a single `.mlmodel` file — and if given a destination path with a different extension, it silently *appends* `.mlmodel` rather than erroring (verified live: naming the destination `BreedClassifier.mlpackage` produced `BreedClassifier.mlpackage.mlmodel` on disk). The script now targets `.mlmodel` directly. Functionally equivalent for Xcode's purposes either way — both formats are picked up by the synchronized group and generate the same `BreedClassifier` Swift class.

## Adding more training data (a second dataset, more photos of an existing breed, a new breed, `mixed_or_uncertain`)

The pipeline is folder-driven and additive, which makes all of these the same operation: neither `extract_features.swift` nor `train_from_features.swift` hardcodes a class list — they train on whatever class folders exist under `data/prepared/{train,test}/` at the time. Nothing needs to be deleted or re-downloaded to add data.

1. **Prepare the new images into the existing folder structure**: `data/prepared/train/<Breed Name>/*.jpg` and `data/prepared/test/<Breed Name>/*.jpg` (roughly an 80/20 split, matching the existing convention). Two cases:
   - **The breed already has a folder** (e.g. adding more "Golden Retriever" photos from a second dataset, or from `mixed_or_uncertain` street-dog photos) — just drop the new images straight into the existing `data/prepared/train/Golden Retriever/` and `.../test/Golden Retriever/` folders, alongside whatever's already there. That class simply gets more training data.
   - **It's a genuinely new breed** (e.g. an Indian-specific breed like Rajapalayam, Mudhol Hound, or Kombai that Stanford Dogs doesn't have) — create the new folder pair. The model grows from 120 classes to 120+N automatically; no code changes anywhere.
2. **Re-run `extract_features.swift`** (or the compiled binary). It only extracts features for images that don't already have a cached `.f32` file — every previously-extracted image (all ~20,580 from the current Stanford Dogs run) is skipped untouched, so this only costs time proportional to the *new* images.
3. **Delete `DoggoCollector/Core/Detection/BreedClassifier.mlmodel`**, then **re-run `train_from_features.swift`**. This refits the classifier head from scratch on the full combined feature cache (old + new) — cheap, since it's pure numeric fitting on cached vectors, no Vision/image work — and re-exports. There's no incremental/online update here; a full refit on the union of everything is the normal, correct way to add data with this pipeline, not a shortcut.

For the specific case of `mixed_or_uncertain` ("Indie mix" in the UI): `CoreMLBreedClassifier`'s 0.65 confidence threshold already treats any low-confidence result as `mixed_or_uncertain` even with zero photos in that folder, so the classifier is useful without it. Populating `data/prepared/train/mixed_or_uncertain/` and `.../test/mixed_or_uncertain/` with real street-dog photos (via the same 3 steps above) turns it into a real 121st class the classifier can predict directly, on top of (not instead of) the existing threshold fallback.

## Licensing

**Never commit or bundle the Stanford Dogs images** — only the trained model file ships in the app. `data/` is gitignored at the repo root (`training/data/`, plus `*.tar`) specifically so this can't happen by accident. The dataset's own terms restrict it to non-commercial research use; training a model from it and shipping the resulting model weights (not the images themselves) is the standard, accepted use of ImageNet-derived datasets like this one — but the raw photos themselves must never end up in version control or the app bundle.
