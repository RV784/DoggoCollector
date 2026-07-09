# Apple Intelligence / Foundation Models — Reference & Integration Notes

This file exists because the Foundation Models framework changed substantially at WWDC 2026 (iOS 27) — **after Claude's training cutoff (January 2026)**. A fresh session should not trust its own training-data memory of this framework's API shape without re-reading this file; the API surface below was verified against the actual installed SDK, not recalled from memory or copied uncritically from blog posts.

## How this was verified (do this again if the SDK updates)

Two sources, in order of trust:

1. **Ground truth — the real SDK's `.swiftinterface` file**, read directly off disk on this machine:
   ```
   /Applications/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface
   ```
   This is the textual public-API interface the Swift compiler itself generates — every type/method signature quoted below was grepped/read directly from this file (iOS 27.0 SDK, Swift 6.4 compiler), not guessed. If a future session needs to re-verify or check for further changes, `find` for `FoundationModels.swiftinterface` under `Xcode-beta.app` and read it the same way — it's far more reliable than web search for exact signatures. There's a companion UIKit overlay module at:
   ```
   .../iPhoneOS.sdk/System/Library/Frameworks/_FoundationModels_UIKit.framework/Modules/_FoundationModels_UIKit.swiftmodule/arm64e-apple-ios.swiftinterface
   ```
   which is where the `UIImage`-based `Attachment` initializer actually lives (see below) — easy to miss if you only read the core module.
2. **WWDC 2026 session + Apple docs** (for framing/context, not exact signatures): ["What's new in the Foundation Models framework"](https://developer.apple.com/videos/play/wwdc2026/241/), [Apple newsroom piece](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/), [developer.apple.com/documentation/FoundationModels](https://developer.apple.com/documentation/FoundationModels).

## What's new in iOS 27 vs. the original (iOS 26 / WWDC 2025) framework

- **Vision/multimodal input** — the on-device model now accepts images in a prompt (previously text-only). This is the change that makes a breed-guess-from-photo feature possible at all.
- Bigger/rebuilt on-device model, better tool-calling, refined guardrails (fewer false-positive refusals).
- Model abstraction: a new `LanguageModel` protocol means the on-device `SystemLanguageModel` is no longer the only option — third-party/cloud models can conform too, and `LanguageModelSession(model: some LanguageModel, ...)` accepts any of them interchangeably. DoggoCollector's code is *written* for a two-tier chain (`SystemLanguageModel` on-device, `PrivateCloudComputeLanguageModel` as escalation) — but the second tier is currently **disabled at runtime by a flag**, see the crash warning immediately below and "DoggoCollector integration."
- New Private Cloud Compute model (bigger context, configurable reasoning levels, also vision-capable) — code exists for this as an explicit second tier after on-device, but **it's flag-gated off by default** because it requires a managed capability entitlement this project doesn't have (see next bullet).

> **⚠️ Crash warning, discovered on-device, read before ever flipping `FoundationModelsInsightProvider.hasPrivateCloudComputeEntitlement` to `true`:** merely *instantiating* `PrivateCloudComputeLanguageModel()` without the `com.apple.developer.private-cloud-compute` entitlement actually present in the app's signed entitlements crashes the entire process immediately with `Fatal error: Process is missing required entitlement: com.apple.developer.private-cloud-compute`. This is **not a throwable Swift error** — it's a hard process trap, and `do`/`catch` cannot intercept it. This entitlement is a **managed capability**: the developer account's Account Holder must submit a Capability Request at developer.apple.com (Certificates, Identifiers & Profiles → the App ID → Capability Requests tab), Apple reviews it against eligibility (App Store Small Business Program enrollment + under-2M-downloads), and only after approval can it be added as an Xcode capability. There is no local/code-only way to enable this — self-declaring the entitlement string in a local `.entitlements` file does nothing without Apple's server-side approval baked into the provisioning profile. **Confirmed on this project**: attempting to use it crashed immediately on the user's physical device test, which is exactly what you'd expect from an unpublished personal app with no Small Business Program enrollment. The fix that's in place now: `PrivateCloudComputeLanguageModel` is never constructed anywhere unless `FoundationModelsInsightProvider.hasPrivateCloudComputeEntitlement` (a `private static let`, currently `false`) is flipped to `true` — and it should stay `false` until someone has confirmed, via Apple's actual approval process, that this entitlement is genuinely present in the signed build.
- New built-in tools (`OCRTool`, `BarcodeReaderTool`, Spotlight-backed local RAG), Dynamic Profiles, an Evaluations framework — none of these are relevant to DoggoCollector's use case and aren't used.

## Exact API surface used (verified against the SDK, not memory)

```swift
import FoundationModels

// Availability — always check before attempting generation.
SystemLanguageModel.default.availability
// enum Availability { case available; case unavailable(UnavailableReason) }
// enum UnavailableReason { case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady }

// iOS 27+: capability check (belt-and-suspenders alongside availability)
SystemLanguageModel.default.capabilities.contains(.vision)   // LanguageModelCapabilities.Capability.vision

// Session — simplest constructor (model defaults to .default, i.e. the on-device model)
let session = LanguageModelSession(instructions: "You are Scout, a warm dog-collecting companion...")

// Structured, image-grounded generation
let response = try await session.respond(generating: GeneratedDogInsight.self) {
    "Look at this dog and give a warm, honest best guess."
    Attachment(uiImage)   // see UIKit-overlay note below
}
response.content   // decoded GeneratedDogInsight, not a raw string
```

**`@Generable` / `@Guide`** (macros from `FoundationModelsMacros`, re-exported via `import FoundationModels`):
```swift
@Generable
private struct GeneratedDogInsight {
    @Guide(description: "...")
    let breedGuess: String

    @Guide(description: "...")
    let isConfident: Bool

    @Guide(.anyOf(["Puppy", "Young adult", "Adult", "Senior"]))
    let ageBracket: String

    @Guide(description: "...", .count(2...3))
    let careTips: [String]

    @Guide(description: "...")
    let didYouKnowFact: String
}
```
- `String`, `Bool`, and `Array where Element: Generable` all conform to `Generable` out of the box (verified in the interface) — a flat struct like the above needs no extra conformance work.
- `GenerationGuide<String>.anyOf([...])` constrains a string field to a fixed set of values — used instead of a nested `@Generable` enum for `ageBracket`, to avoid uncertainty about exactly how enum+`@Generable` interplay works; simpler and verified to compile.
- `GenerationGuide<[Element]>.count(_ range: ClosedRange<Int>)` (also `.count(_:)`, `.minimumCount`, `.maximumCount`, `.element(_:)`) constrains array size — used for `careTips` needing 2–3 items.
- Other `GenerationGuide` constraints exist for `Int`/`Float`/`Double`/`Decimal` (`.minimum`, `.maximum`, `.range`) and `String` (`.constant`, `.pattern(_ regex:)`) — not needed here but available.

**Image attachments — the UIKit overlay gotcha**: the core `FoundationModels` module only defines
```swift
extension Attachment where Content == ImageAttachmentContent {
    public init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil)
    public init(_ ciImage: CIImage, orientation: CGImagePropertyOrientation? = nil)
    public init(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil)
    public init(imageURL: URL, orientation: CGImagePropertyOrientation? = nil)
}
```
**There is no `UIImage` initializer in the core module.** It lives in `_FoundationModels_UIKit` (`extension Attachment where Content == ImageAttachmentContent { public init(_ uiImage: UIImage, orientation: UIImage.Orientation? = nil) }`), which is a Swift **cross-import overlay** — it activates automatically the moment a file imports both `FoundationModels` and `UIKit` (which SwiftUI transitively provides in this codebase's existing style of `import SwiftUI` without an explicit `import UIKit`). No explicit `import _FoundationModels_UIKit` is needed or possible as a normal import; just `import FoundationModels` alongside the existing `import SwiftUI`/UIKit access is sufficient. This is an easy detail to miss if you only skim the core module's interface.

**Errors**: `session.respond(...)` is `throws`. As of iOS 27, the old `LanguageModelSession.GenerationError` cases (`.guardrailViolation`, `.decodingFailure`, etc.) are deprecated in favor of a unified `LanguageModelError` enum (`.contextSizeExceeded`, `.rateLimited`, `.guardrailViolation`, `.refusal`, `.unsupportedCapability`, `.unsupportedTranscriptContent`, `.unsupportedGenerationGuide`, `.unsupportedLanguageOrLocale`, `.timeout`). DoggoCollector's integration doesn't switch on specific cases at this generic-error level — see the PCC-specific errors below for the one place it does.

**`PrivateCloudComputeLanguageModel`** (verified in the same `.swiftinterface`, iOS 27+ only):
```swift
final public class PrivateCloudComputeLanguageModel: Sendable {
    public init()   // trivially constructible — no API key, no account object

    final public var availability: Availability { get }
    // enum Availability { case available; case unavailable(UnavailableReason) }
    // enum UnavailableReason { case deviceNotEligible, systemNotReady }
    // (note: different UnavailableReason cases than SystemLanguageModel's — no
    // .appleIntelligenceNotEnabled case here)

    final public var quotaUsage: QuotaUsage { get }
    // struct QuotaUsage { var status: Status; var isLimitReached: Bool { get };
    //   var limitIncreaseSuggestion: LimitIncreaseSuggestion?; var resetDate: Date? }
    // enum Status { case belowLimit(BelowLimit); case limitReached(LimitReached) }
    // struct BelowLimit { var isApproachingLimit: Bool }

    final public var contextSize: Int { get async throws }  // async — asks the server
}
extension PrivateCloudComputeLanguageModel: LanguageModel {
    final public var capabilities: LanguageModelCapabilities { get }  // includes .vision
}
extension PrivateCloudComputeLanguageModel {
    public enum Error: Swift.Error, LocalizedError {
        case networkFailure(NetworkFailure)
        case quotaLimitReached(QuotaLimitReached)   // carries limitIncreaseSuggestion, resetDate
        case serviceUnavailable(ServiceUnavailable)
    }
}
```
Conforms to `LanguageModel` exactly like `SystemLanguageModel`, so it drops straight into the same `LanguageModelSession(model:, instructions:)` initializer and the same generic `respond(generating:)` call — no separate code path needed, just a different concrete `model:` argument (see the generic `generate<Model: LanguageModel>(using:image:)` helper in `FoundationModelsInsightProvider.swift`).

**Eligibility/quota, verified via web research (not the SDK — this is an account/business-terms fact, not an API shape)**: free PCC access for third-party apps requires the developer account be enrolled in the **App Store Small Business Program** with **fewer than 2 million total first-time downloads across the entire account** (not just this app). There is no paid tier beyond that threshold — exceeding it means migrating off within ~6 months, no purchase option. Quota is metered per-user against their iCloud account with a daily reset (`resetDate`). **This isn't just a theoretical constraint** — it's exactly what blocks this project right now: DoggoCollector's personal/unpublished developer account has no Small Business Program enrollment, so it cannot currently be granted the `com.apple.developer.private-cloud-compute` managed capability at all, which is why tier 2 is flag-gated off (see crash warning above).

## DoggoCollector integration

- **New file**: `Mechanic/FoundationModelsInsightProvider.swift` — conforms to the existing `DogInsightProviding` protocol (`Mechanic/DogInsightProviding.swift`), added when the four new flows were built. No protocol changes were needed; `insight(for:) async` was already the right shape.
- **Three-tier fallback chain, on-device first — an explicit user decision, tier 2 currently disabled**:
  1. **`SystemLanguageModel.default`** (on-device, no network) is tried first. If its availability/vision-capability check fails, if generation throws, **or if it succeeds but comes back with `isConfident: false`**, the code escalates to tier 2 rather than accepting a low-confidence on-device answer.
  2. **`PrivateCloudComputeLanguageModel()`** (Apple's server model) is the intended escalation tier, and the code for it is fully written — but it's gated behind `FoundationModelsInsightProvider.hasPrivateCloudComputeEntitlement`, a `private static let` currently `false`. **`PrivateCloudComputeLanguageModel` is never constructed anywhere unless that flag is true** — not as a stored property, not eagerly — specifically because merely instantiating it without the managed capability entitlement crashes the whole process (see the crash warning earlier in this file). When the flag is true, the tier checks availability, vision capability, and that the per-user quota isn't already exhausted (`!quotaUsage.isLimitReached`) before attempting, and its result is accepted whether confident or not (there's no tier 3 escalation for "PCC was unconfident," only for PCC being unavailable/disabled/throwing).
  3. **`MockDogInsightProvider`** (the original deterministic/seeded mock built for the UI-first pass) is the final fallback — **kept, not deleted**. With tier 2 disabled, this is effectively the immediate fallback whenever tier 1 is unavailable/unconfident/errors. The UI never knows or cares which tier actually answered.
  - **Why PCC is in the code at all if it's disabled**: this was a deliberate, explicit exception to Phase 1's "local-only, no backend" philosophy (decision #4 in `CLAUDE.md`), made directly by the user after being walked through the eligibility/quota/network tradeoffs — reasoning being "the backend is given by Apple in the form of `PrivateCloudComputeLanguageModel`, so might as well use it." The crash discovered on-device doesn't invalidate that decision, it just means the entitlement isn't actually available yet — the code is left in place, correctly gated off, ready for whenever (if ever) this project gets that entitlement. Don't rip out the PCC code path; just don't flip the flag without confirming the entitlement is real first.
  - Both tiers' failures are logged via `print(...)` (which tier, and the error's `localizedDescription`) rather than swallowed silently — useful when the user is testing on-device and wants to know whether a bad guess came from a real low-confidence model answer vs. an availability failure that fell through to the mock.
- **Shared generic helper**: `private func generate<Model: LanguageModel>(using model: Model, image: UIImage) async throws -> GeneratedDogInsight` builds the session and calls `respond(generating:)` — reused for both `SystemLanguageModel` and `PrivateCloudComputeLanguageModel` since both conform to `LanguageModel` and the session initializer is generic over it. Avoids duplicating the prompt-building code per tier.
- **Prompt design**: one `Attachment` (the dog's `UIImage`, decoded from `dog.imageData`) plus a short instruction, with the *system* instructions (not the per-call prompt, shared across both model tiers) carrying Scout's persona/tone and the hard rule "breed is always a guess, never medical/legal advice, prefer 'Indie mix' or another mixed-breed guess for street dogs unless purebred features are obvious" — matching the design brief's "mixed/indie is the primary case" framing from decision #8 in `CLAUDE.md`. The instructions also permit brief breed-relevant petting/diet tips (the user's addition) — still bounded by "never medical or legal advice."
- **`InsightPanelView`/`ShareView`** now instantiate `FoundationModelsInsightProvider()` instead of `MockDogInsightProvider()` directly — both already depended only on the `DogInsightProviding` protocol, so this was a one-line swap at each call site.

## Practical gotchas (read before debugging "AI isn't working")

1. **The PCC entitlement crash (see warning above) is the single most important gotcha in this file.** If you're tempted to flip `hasPrivateCloudComputeEntitlement` to `true` to "finish" the escalation tier: don't, unless you've personally confirmed (via Apple's Capability Requests flow, approval, and an Xcode capability actually added to this target) that the entitlement is real. Getting this wrong doesn't throw a catchable error, it crashes the app instantly.
2. **Simulator vs. device**: live Foundation Models inference is unreliable/effectively unsupported in the iOS Simulator, even though the code compiles and links fine there. This is why **the user tests this feature on their physical device** ("Rajat's iPhone 17e", iOS 27 beta, Apple Intelligence/Siri AI enabled in Settings) rather than the Simulator this whole project has otherwise been built and tested against. Claude cannot verify actual model output — only that the code compiles (`xcodebuild` against both a Simulator destination and the real device destination). Don't report this feature as "verified working" without the user confirming on-device.
3. **The Simulator's existing camera fallback** (`CameraViewModel.simulatorFallbackImage()`) produces a solid-color placeholder `UIImage` with no real dog in it. If `FoundationModelsInsightProvider` ever runs against one of these (e.g. testing on Simulator anyway), expect low confidence / a generic guess — that's the *correct* behavior for a fake photo, not a bug.
4. **First-call latency**: on-device model load can make the first real generation call in a session slower than the mock's instant resolution. `InsightPanelView`'s existing 700ms minimum-loading race (built during the mock-only pass, see `CLAUDE.md` Flow 1 section) is a floor, not a ceiling. (If tier 2 is ever re-enabled, factor in a second network round-trip on top of this whenever tier 1 comes back unconfident.)
5. **On-device inference needs no accounts/API keys/network at all** — the only network dependency in this feature is the currently-disabled PCC tier. If someone reports this feature "needing internet," that's a red flag something's wrong, since tier 1 + tier 3 (the only tiers actually active right now) are both fully offline.

## Open questions / explicitly not done

- **Getting the actual `com.apple.developer.private-cloud-compute` entitlement** — would require the account's Account Holder to submit a Capability Request at developer.apple.com and get it approved (gated on Small Business Program enrollment + eligibility), which is unlikely to apply to this personal/unpublished project. Not pursued; tier 2 stays flag-gated off until/unless that changes.
- **Reasoning levels** (`ContextOptions(reasoningLevel:)`, available when calling `respond` with a `contextOptions:` argument) are **not used** for the PCC tier — the current call uses the same simple `respond(generating:)` overload for both tiers via the shared generic helper. Moot while tier 2 is disabled anyway.
- **Evaluations framework** (new WWDC26 tool for measuring prompt/output quality over time) is not set up — no eval harness exists for this feature.
- **Care/Community flows (Flow 2/3)** are unrelated to this file and remain fully mocked per `CLAUDE.md` decision #8 — don't conflate "we did Apple Intelligence for Flow 1" with "the other mocked flows are also decided now."
