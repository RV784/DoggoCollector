//
//  FoundationModelsInsightProvider.swift
//  DoggoCollector
//
//  Real "Scout's Sniff" data source — Apple Intelligence via the iOS 27
//  Foundation Models framework. See AppleIntelligence.md at the project root
//  for the full API reference this was built against (verified directly off
//  the installed SDK, since this framework changed substantially at
//  WWDC 2026, after training cutoff).
//
//  Text-only as of the breed-classifier pass: breed now comes from
//  CoreMLBreedClassifier (a real trained model), not a photo-grounded guess
//  from the language model — FM's job here is just to write age/tips/fact
//  given an already-known breed name. This also removes the Attachment(image)
//  call that was the exact crashing symbol reference in Known Issue #13's
//  on-device dyld failure (see CLAUDE.md) — a motivated side-benefit, not a
//  coincidence.
//
//  Three-tier chain, on-device first:
//  1. SystemLanguageModel (on-device, no network) — tried first.
//  2. PrivateCloudComputeLanguageModel (Apple's server model) — used only if
//     the on-device model is unavailable or errors ("Apple-provided backend"
//     per the user's explicit decision — this is the one exception to
//     Phase 1's local-only philosophy, see decision #9 in CLAUDE.md).
//     CURRENTLY DISABLED (see hasPrivateCloudComputeEntitlement below) —
//     merely *instantiating* PrivateCloudComputeLanguageModel without the
//     com.apple.developer.private-cloud-compute entitlement actually present
//     in the app's signed entitlements is an immediate, uncatchable fatal
//     process crash ("Process is missing required entitlement..."), not a
//     throwable Swift error — do/catch cannot guard against it. That
//     entitlement is a *managed capability*: it must be requested and
//     approved by Apple for this developer account first (gated on App Store
//     Small Business Program enrollment), then added as an Xcode capability
//     — there is no client-side/code fix. See AppleIntelligence.md for the
//     full story.
//  3. MockDogInsightProvider's warm generic content for age/tips/fact —
//     final fallback if both model tiers are unavailable or fail. Its own
//     breedGuess/isConfident are NOT used — breed always comes from the
//     classifier now, even on this fallback path.
//

import FoundationModels
import UIKit

@Generable
private struct GeneratedDogInsight {
    @Guide(.anyOf(["Puppy", "Young adult", "Adult", "Senior"]))
    let ageBracket: String

    @Guide(description: "3 to 4 short, warm, general dog-care tips relevant to meeting this dog. Never medical advice.", .count(3...4))
    let careTips: [String]

    @Guide(description: "One warm, general did-you-know fact about this breed, or about street dogs/mixed breeds/community dog care if uncertain. Never medical or legal advice.")
    let didYouKnowFact: String
}

struct FoundationModelsInsightProvider: DogInsightProviding {
    private let fallback = MockDogInsightProvider()
    private let breedClassifier: BreedClassifying = CoreMLBreedClassifier()

    /// Flip to true ONLY once this app's bundle ID has actually been granted
    /// the `com.apple.developer.private-cloud-compute` managed capability by
    /// Apple (Capability Requests → approval → added in Xcode's Signing &
    /// Capabilities) — see the file-header comment and AppleIntelligence.md.
    /// `PrivateCloudComputeLanguageModel` must never be instantiated while
    /// this is false; doing so crashes the whole process, not just this call.
    private static let hasPrivateCloudComputeEntitlement = false

    private static let instructions = """
        You are Scout, a warm and encouraging companion in a dog-collecting app. Someone just met a real \
        dog — often a mixed-breed street or community dog — and already knows (or has a good guess at) \
        its breed. Help them understand this kind of dog a little better: a plausible age bracket, a \
        few friendly care tips, and one fun fact. Never give medical or legal advice. Keep everything \
        brief and warm, never clinical or authoritative. You may give a few helpful petting or diet tips \
        typical for that breed.
        """

    func insight(for dog: CaughtDog) async -> DogInsight {
        await ensureClassified(dog)
        let displayBreed = dog.classifiedDisplayBreed ?? "Indie mix"
        let isConfident = dog.isBreedConfident

        if let generated = await generateTextOnly(displayBreed: displayBreed, isConfident: isConfident) {
            return DogInsight(
                breedGuess: displayBreed,
                isConfident: isConfident,
                ageBracket: DogAgeBracket(rawValue: generated.ageBracket) ?? .adult,
                careTips: generated.careTips,
                didYouKnowFact: generated.didYouKnowFact
            )
        }

        // Tier 3 — both model tiers unavailable or failed. Breed still comes
        // from the classifier, not the mock's own random breedGuess.
        let mockInsight = await fallback.insight(for: dog)
        return DogInsight(
            breedGuess: displayBreed,
            isConfident: isConfident,
            ageBracket: mockInsight.ageBracket,
            careTips: mockInsight.careTips,
            didYouKnowFact: mockInsight.didYouKnowFact
        )
    }

    /// Lazy backfill for catches made before the classifier existed: if
    /// there's no classification yet and the photo decodes, classify now and
    /// persist onto the dog (SwiftData autosave picks up the mutation) — old
    /// dogs get a real breed the first time their card is opened. Updates
    /// `breedLabel` too, not just `classifiedBreedRaw`/`breedConfidence` —
    /// `DoggoCardView`'s tag, the grid tile, and Shelter Pass's BREED cell
    /// all read `breedLabel` directly (not the insight), so without this
    /// they'd stay stuck on the old whimsical label even after backfill.
    private func ensureClassified(_ dog: CaughtDog) async {
        guard dog.classifiedBreedRaw == nil else { return }
        guard let uiImage = DogPhoto.image(from: dog.imageData, size: .card, cacheKey: dog.id.uuidString),
              let cgImage = uiImage.cgImage else { return }
        let result = await breedClassifier.classify(cgImage)
        dog.classifiedBreedRaw = result?.breedName
        dog.breedConfidence = result?.confidence
        if let result {
            dog.breedLabel = result.displayName
        }
    }

    private func generateTextOnly(displayBreed: String, isConfident: Bool) async -> GeneratedDogInsight? {
        let prompt = isConfident
            ? "Someone just met a dog that looks like a \(displayBreed). Suggest an age-bracket guess, 3-4 friendly care tips, and one fun fact about this kind of dog."
            : "Someone just met a lovable mixed-breed street dog (an \"Indie mix\"). Suggest an age-bracket guess, 3-4 friendly care tips, and one fun fact about mixed-breed or community dogs."

        // Tier 1 — on-device, no network. Escalate to tier 2 only if
        // unavailable or it throws (no more confidence-based escalation —
        // that was about the AI's own breed guess, which no longer exists
        // here; breed is already known from the classifier).
        if case .available = SystemLanguageModel.default.availability {
            do {
                return try await generate(using: SystemLanguageModel.default, prompt: prompt)
            } catch {
                print("FoundationModelsInsightProvider: on-device generation failed — \(error.localizedDescription)")
            }
        }

        // Tier 2 — Apple's Private Cloud Compute model. The type is only
        // ever touched inside this flag check — see its declaration for why.
        if Self.hasPrivateCloudComputeEntitlement {
            let pccModel = PrivateCloudComputeLanguageModel()
            if case .available = pccModel.availability,
               !pccModel.quotaUsage.isLimitReached {
                do {
                    return try await generate(using: pccModel, prompt: prompt)
                } catch {
                    print("FoundationModelsInsightProvider: Private Cloud Compute generation failed — \(error.localizedDescription)")
                }
            }
        }

        return nil
    }

    private func generate<Model: LanguageModel>(using model: Model, prompt: String) async throws -> GeneratedDogInsight {
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let response = try await session.respond(generating: GeneratedDogInsight.self) {
            prompt
        }
        return response.content
    }
}
