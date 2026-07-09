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
//  Three-tier chain, on-device first:
//  1. SystemLanguageModel (on-device, no network) — tried first.
//  2. PrivateCloudComputeLanguageModel (Apple's server model) — used only if
//     the on-device model is unavailable, errors, or comes back unconfident
//     ("Apple-provided backend" per the user's explicit decision — this is
//     the one exception to Phase 1's local-only philosophy, see decision #9
//     in CLAUDE.md). CURRENTLY DISABLED (see hasPrivateCloudComputeEntitlement
//     below) — merely *instantiating* PrivateCloudComputeLanguageModel
//     without the com.apple.developer.private-cloud-compute entitlement
//     actually present in the app's signed entitlements is an immediate,
//     uncatchable fatal process crash ("Process is missing required
//     entitlement..."), not a throwable Swift error — do/catch cannot guard
//     against it. That entitlement is a *managed capability*: it must be
//     requested and approved by Apple for this developer account first
//     (gated on App Store Small Business Program enrollment), then added as
//     an Xcode capability — there is no client-side/code fix. See
//     AppleIntelligence.md for the full story.
//  3. MockDogInsightProvider's warm generic content — final fallback if both
//     model tiers are unavailable or fail (or tier 2 is disabled). The UI
//     never needs to know which tier answered.
//

import FoundationModels
import UIKit

@Generable
private struct GeneratedDogInsight {
    @Guide(description: "Best-guess breed or mix, e.g. 'Indie mix', 'Labrador mix', 'Golden Retriever mix'. Most dogs met this way are mixed-breed street/community dogs, so prefer 'Indie mix' or another plausible mixed-breed guess unless the photo clearly shows purebred features.")
    let breedGuess: String

    @Guide(description: "True only if reasonably confident in the breed guess from the photo. False if the photo is unclear, doesn't clearly show a dog, or the breed is genuinely hard to tell.")
    let isConfident: Bool

    @Guide(.anyOf(["Puppy", "Young adult", "Adult", "Senior"]))
    let ageBracket: String

    @Guide(description: "3 to 4 short, warm, general dog-care tips relevant to meeting this dog. Never medical advice.", .count(3...4))
    let careTips: [String]

    @Guide(description: "One warm, general did-you-know fact about street dogs, mixed breeds, or community dog care. Never medical or legal advice.")
    let didYouKnowFact: String
}

private extension DogInsight {
    init(_ generated: GeneratedDogInsight) {
        self.init(
            breedGuess: generated.breedGuess,
            isConfident: generated.isConfident,
            ageBracket: DogAgeBracket(rawValue: generated.ageBracket) ?? .adult,
            careTips: generated.careTips,
            didYouKnowFact: generated.didYouKnowFact
        )
    }
}

struct FoundationModelsInsightProvider: DogInsightProviding {
    private let fallback = MockDogInsightProvider()

    /// Flip to true ONLY once this app's bundle ID has actually been granted
    /// the `com.apple.developer.private-cloud-compute` managed capability by
    /// Apple (Capability Requests → approval → added in Xcode's Signing &
    /// Capabilities) — see the file-header comment and AppleIntelligence.md.
    /// `PrivateCloudComputeLanguageModel` must never be instantiated while
    /// this is false; doing so crashes the whole process, not just this call.
    private static let hasPrivateCloudComputeEntitlement = false

    private static let instructions = """
        You are Scout, a warm and encouraging companion in a dog-collecting app. You look at photos of \
        real dogs — often mixed-breed street or community dogs — and give a friendly, honest best guess \
        about them. Breed is always a guess, never a certainty; say so implicitly by being modest. Never \
        give medical or legal advice. Keep everything brief and warm, never clinical or authoritative. You may give a few helpful petting or diet advice for that breed of the dog
        """

    func insight(for dog: CaughtDog) async -> DogInsight {
        guard let imageData = dog.imageData, let image = UIImage(data: imageData) else {
            return await fallback.insight(for: dog)
        }

        // Tier 1 — on-device, no network. Escalate to tier 2 if unavailable,
        // if it throws, or if it comes back but isn't confident in its guess.
        if case .available = SystemLanguageModel.default.availability,
           SystemLanguageModel.default.capabilities.contains(.vision) {
            do {
                let generated = try await generate(using: SystemLanguageModel.default, image: image)
                if generated.isConfident {
                    return DogInsight(generated)
                }
            } catch {
                print("FoundationModelsInsightProvider: on-device generation failed — \(error.localizedDescription)")
            }
        }

        // Tier 2 — Apple's Private Cloud Compute model. Accepted whether or
        // not it's confident, since this is already the escalation path;
        // skipped if unavailable or the per-user quota is already exhausted.
        // The type is only ever touched inside this flag check — see its
        // declaration for why.
        if Self.hasPrivateCloudComputeEntitlement {
            let pccModel = PrivateCloudComputeLanguageModel()
            if case .available = pccModel.availability,
               pccModel.capabilities.contains(.vision),
               !pccModel.quotaUsage.isLimitReached {
                do {
                    let generated = try await generate(using: pccModel, image: image)
                    return DogInsight(generated)
                } catch {
                    print("FoundationModelsInsightProvider: Private Cloud Compute generation failed — \(error.localizedDescription)")
                }
            }
        }

        // Tier 3 — both model tiers unavailable or failed.
        return await fallback.insight(for: dog)
    }

    private func generate<Model: LanguageModel>(using model: Model, image: UIImage) async throws -> GeneratedDogInsight {
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let response = try await session.respond(generating: GeneratedDogInsight.self) {
            "Here's a photo of a dog someone just met. Give your best guess at breed/mix, an age bracket, a couple of care tips, and a fun fact."
            Attachment(image)
        }
        return response.content
    }
}
