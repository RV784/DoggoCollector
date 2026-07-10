# Breed Classifier Training Report (full dataset, via CreateMLComponents)

Date: 2026-07-10 14:17:38 +0000
Class count: 120
Train samples: 16418
Test samples: 4162
Pipeline: CreateMLComponents.ImageFeaturePrint -> LogisticRegressionClassifier (features extracted one image at a time to work around the CVPixelBufferPool crash in MLImageClassifier's bulk extraction — see CLAUDE.md Known Issue #16)

## Accuracy
- Training: 80.10%
- Test (held-out): 67.04%

## 15 worst confusion pairs (true -> predicted, count)
- Eskimo Dog -> Siberian Husky: 14
- Toy Poodle -> Miniature Poodle: 12
- Standard Schnauzer -> Miniature Schnauzer: 12
- Irish Wolfhound -> Scottish Deerhound: 11
- English Foxhound -> Walker Hound: 11
- Shetland Sheepdog -> Collie: 10
- Staffordshire Bullterrier -> American Staffordshire Terrier: 9
- Scottish Deerhound -> Irish Wolfhound: 8
- Siberian Husky -> Eskimo Dog: 8
- Lhasa -> Shih Tzu: 8
- Miniature Schnauzer -> Standard Schnauzer: 8
- Miniature Poodle -> Toy Poodle: 8
- Miniature Poodle -> Standard Poodle: 8
- Collie -> Shetland Sheepdog: 8
- Shih Tzu -> Lhasa: 7
