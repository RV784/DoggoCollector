# Design Brief — The Shelter Pass, Reimagined

**For: Claude Design**
**Product: DoggoCollector (iOS 27, SwiftUI)**
**Feature: Guardian Mode → Shelter Pass**
**Status: full redesign. The current version is a plain white document; we want the opposite.**

---

## 0. The one-line mission

Make the single most beautiful, most *earned-feeling* care credential a person has ever held on a phone — a pass that a street-dog caretaker is **proud** to mint, watch assemble, and hand to a shelter, a vet, or an adopter. It should feel like issuing a passport for a dog nobody else was looking after.

**Do not hold back.** Metal shaders, foil, light, parallax, motion, haptics, ceremony. If you are ever choosing between "tasteful and safe" and "breathtaking," choose breathtaking — then make it tasteful *within* breathtaking. The only hard limits are the ones in §9 (honesty, print-safety, accessibility, our palette). Everything else is yours to push.

---

## 1. What DoggoCollector is (so the pass belongs)

DoggoCollector is a warm, playful iOS app where you "catch" real street dogs you meet — point your camera, catch the dog, and it becomes a collectible card in *Your Pack*. The visual identity is **"Sunny Fetch"**: marigold + cream, rounded storybook shapes, a simple-shapes mascot dog named **Scout**, a bouncy, kind, optimistic tone. It is deliberately *not* a generic minimal-AI-template look — it's handmade, sunny, and a little joyful.

**Guardian Mode** is the app's most serious, most meaningful layer. When you don't just catch a dog but decide to *look after* a specific street dog, you "pledge" and it becomes your **Ward**. Guardian Mode has grown a lot: a living **Dossier**, one-tap **care logging** (fed / medicated / injury check / vaccinated), **medication schedules** with reminders, **medical records** (photos + PDFs), an **assigned clinic** with one-tap calling, **sterilization status**, and the ability to **hand over** guardianship to someone else.

The **Shelter Pass** is the crown of Guardian Mode: the printable / shareable summary of everything you know and have done for this dog. Right now it's a flat white page. It has grown severely under-designed relative to the feature behind it — and it doesn't even show the dog's photo. That's what we're fixing.

---

## 2. What the Shelter Pass actually IS — and its two lives

The Shelter Pass is a **self-issued care record** for a specific street dog. Its real-world job: when the dog goes to a shelter, a vet, a rescue, or a new adopter, the caretaker sends or prints this so the receiving person instantly knows *who this dog is and what care they've already had.* It reduces duplicate vaccinations, communicates temperament, names a clinic that knows the dog, and — quietly — tells the receiver "someone loved this dog; please continue."

It has **two lives**, and the design must serve both, distinctly:

### Life A — **The Living Pass** (on-screen, in-app)
This is the experience of *creating and beholding* the pass inside the app. This is where you go maximal. The pass should feel **minted** — assembled in front of the user with light, motion, depth, foil, and a metal-shader background that makes the whole screen feel like a precious object catching the light. This moment is a reward. It should give the caretaker a small lump in the throat.

### Life B — **The Artifact** (exported PDF / shared image / print)
This is what actually leaves the phone. It must be **credible, calm, legible, and print-safe**: high-contrast, clean typographic hierarchy, works in grayscale, survives a cheap inkjet, reads clearly to a stranger at a shelter desk in ten seconds. The shimmer and shaders **cannot and must not** print — so every luminous effect in Life A needs a **flat, elegant analogue** in Life B (foil → a refined gold-ink gradient / spot-varnish suggestion; emboss → a hairline + soft inner shadow that still reads on paper; guilloché → a genuinely printable fine-line pattern).

**Design both. Show the relationship between them.** The magic is that the flat artifact is visibly the *same object* as the living pass, just at rest — like a hologram card photographed under flat light.

---

## 3. Everything the pass must present (the data inventory)

Design the layout around **real data the app already has.** Group and prioritize it. Not every field is always present — see §8 for empty/edge states.

**Identity (the hero block)**
- **Photo of the dog** — REQUIRED, currently missing, must become the hero. Comes from the dog's photo gallery (a real photo the caretaker took). Frame it with intention — think passport/ID portrait but beautiful, not clinical.
- **Name** (e.g. "Pepper")
- **Serial number** — `#001`, `#014` … an official-feeling running ID ("#" + zero-padded). Lean into this; it's a credibility and collectibility motif.
- **Record title / kind** — currently "STREET DOG CARE RECORD"
- **Issued date**
- **Breed** — tagged **EST.** (an AI/photo-based estimate) or plain when the caretaker corrected it by hand
- **Approx. age**
- **Location / neighborhood** — tagged **OBS.**
- **Guardian** — the caretaker's handle (e.g. `@rajat`), tagged **OBS.**

**Health & status**
- **Sterilization status** — one of: *Spayed/Neutered (done)*, *Not yet*, *Unknown*. This is a headline health fact for street-dog welfare — give it prominence and a clear, calm status treatment.
- **Vaccinations** — derivable from care log entries of type *Vaccinated* and from medical records
- **Active medications** — drug name, dosage (free text, e.g. "as written on the prescription"), frequency (every N hours), start date. *(Never invent or suggest dosages — display only.)*
- **Assigned clinic** — name, address, phone. This is huge for a shelter: "this dog has a vet who knows them." Make the clinic feel like a real, callable contact.

**The story / provenance**
- **Logged care history / timeline** — a list of dated care actions: *Fed*, *Medicated*, *Injury check*, *Vaccinated*, each with an optional note and a date. This is the emotional proof-of-love. Design it as a **timeline / ledger**, not a boring table.
- **Medical records** — count / presence of attached documents (vet letters, prescriptions). The pass itself is a summary; it can *reference* that N records exist rather than embed them.

**Provenance tags — keep these, they are a feature, not clutter:**
- **EST.** = an AI/photo-based estimate (breed, age) — an honest "our best guess."
- **OBS.** = observed / logged by the guardian — a first-hand fact.
- A tiny legend explains both. This honesty is part of what makes the pass *trustworthy* rather than a forged certificate. Design these tags to be elegant and quiet, but never remove them.

**Attribution (always visible)**
- Issued via **DoggoCollector**, by guardian **@handle**. The pass is proudly self-issued — it should *look* official and premium, but it must always read as "a caretaker's record, issued through DoggoCollector," never impersonate a real government or veterinary authority. (See §9.)

---

## 4. The creative north star — "an issued credential, minted with love"

Reach for the feeling of holding something **official *and* precious**: a passport, a vaccination booklet, a founder's certificate, a graded holographic trading card, an Apple Wallet pass, a minted collectible, a wax-sealed letter. Borrow their *gravitas* and their *craft motifs* — seals, embossing, guilloché line-work, foil, serial numbers, "ISSUED" stamps, ledger lines, microtype — but render them in **Sunny Fetch**: warm, rounded, kind, gold-and-cream, never cold or corporate.

The tension to nail: **"different but similar, all at once."** The pass must be unmistakably from the same app as the playful collection cards and Scout — same warmth, same marigold, same soul — yet clearly a *different class of object*: heavier, more serious, more permanent, more *earned*. The collection card is a sticker you collect for fun; the Shelter Pass is a **document you'd frame.** Show us how the family resemblance survives the promotion in status.

---

## 5. Life A — The Living Pass (go maximal here)

Design the full on-screen experience. This is where the ambition lives.

**5.1 The metal-shader background (the thing the user specifically asked for)**
The area *behind and around* the pass should be a living, luminous, **metallic / foil / liquid-light field** that respects our palette (warm gold, marigold, cream, deep ink) but feels like precious metal catching light — brushed gold, molten marigold, iridescent warm foil, aurora-in-honey. It should:
- Slowly, continuously move (never static) — a slow drift, a breathing sheen.
- React to **device tilt** (CoreMotion parallax) so the metal *catches the light* as you move the phone — this is the single most "wow" affordance; make the pass feel physical.
- Optionally react to touch (a highlight that follows the finger, like tilting a foil card).
- Stay firmly warm — this is *gold and sunlight*, not chrome or cyberpunk neon. It must read as "the same universe as marigold + cream," just elevated to metal.
- Feel expensive and calm, not busy. A quiet, deep shimmer beats a loud rainbow.

This is achievable in SwiftUI on iOS 27 — you have **Metal shaders** (`ShaderLibrary` + `.colorEffect` / `.distortionEffect` / `.layerEffect`), **`MeshGradient`** (animatable gradient meshes), **`Canvas`**, **`TimelineView`** for continuous animation, **CoreMotion** for tilt parallax, and **Liquid Glass** materials. Design as if all of these are on the table — because they are. Give us the *look and behavior*; we'll build the shader.

**5.2 The pass itself — foil, emboss, depth**
The card/document that sits in that field should feel like a physical printed-and-foiled object:
- A subtle **holographic / foil sweep** across the serial number, the seal, or a header rule — a band of light that travels as you tilt (paired with the metal background).
- **Emboss / deboss / letterpress** suggestions on the title, the seal, the rules.
- Real **depth**: soft, believable shadow; the pass floats slightly above the metal field.
- A **seal or crest** — a Scout-derived emblem (a paw, Scout's silhouette, a sunburst) rendered as an embossed foil seal / wax stamp. This is the pass's signature mark. Design it.
- The **dog's photo** framed like a treasured portrait — could carry a faint foil frame, a rounded ID-photo mat, or a subtle inner light. On-screen, consider letting a live-photo gently breathe if present (we support live photos), but the *export* is always the still.

**5.3 "Made in front of the user" — the Issuance Ceremony (§7 storyboards this)**
The pass must not just *appear.* It must be **issued** — assembled, stamped, sealed, and lit, in a short, deliberate, goosebump-worthy sequence. This is the heart of Life A.

---

## 6. Life B — The Artifact (make it credible and print-safe)

Design the exported PDF / shared image as its own deliverable — same object, at rest, flattened for the world.

- **One page**, portrait, roughly 612×900pt (US-Letter-ish ratio) — this is the render target today; you may propose a different aspect if it's better, but keep it a single clean page.
- **High contrast, grayscale-safe.** Assume it may be printed on a bad inkjet or faxed at a shelter. Every critical fact must survive losing color. Test your hierarchy in pure black-and-white in your head.
- **Foil → flat analogue:** replace luminous foil with a refined static gold gradient / spot-varnish *suggestion* and fine embossed hairlines that still read on paper. The serial number and seal should still feel special when flat.
- **Guilloché / fine-line motifs are welcome** here — they *print beautifully* and scream "official document" (currency, passports, certificates use them). A subtle warm guilloché border or security-pattern band is a great printable way to carry the "credential" feeling into Life B.
- **The photo prints well** — a clean, well-framed portrait with a legible caption.
- **Provenance legend (EST./OBS.) stays**, small and clear.
- **Attribution** (issued via DoggoCollector, by @handle, date, serial) is always present — this is what makes a stranger trust it.
- It should look like something a shelter would **keep on file** without embarrassment — closer to a vaccination certificate than a party invite, but still unmistakably warm.

**Deliver the export layout as a separate artboard from the living-screen layout, and annotate what changes between them.**

---

## 7. The Issuance Ceremony — storyboard this in detail

This is the "made in front of you" moment. Storyboard a short (~2–3.5s), skippable, *once-per-issuance* sequence. Make it feel like a document being officially minted. A suggested beat sheet (improve on it — this is a floor, not a ceiling):

1. **Summon** — the metal field ignites/warms into being behind a blank or wireframe pass.
2. **The photo drops in** — the dog's portrait settles into its frame with a soft light bloom. *This is the emotional anchor — the dog appears first.*
3. **Fields stamp on** — name, serial, breed, location, guardian animate/stamp into place in a considered order (identity → status → story), each with a crisp micro-motion. The serial number could *tick up* like an odometer to its final value.
4. **The seal presses** — the Scout crest/seal thuds down (emboss + foil catch), paired with a firm **haptic**. This is the climax beat.
5. **"ISSUED" + date** lands, foil sweep travels across the header, the metal field settles into its calm continuous drift.
6. **Rest state** — the pass now sits, breathing, tiltable, ready to Print or Share.

Specify: timing, easing, stagger, what carries a **haptic** (the seal press is a must; consider the photo-drop and the final settle), and the **Reduce-Motion** version (a graceful cross-fade assembly — no less premium, just no large motion; the pass still *arrives with dignity*).

---

## 8. States & edge cases (design these, don't hand-wave them)

The pass must look intentional and beautiful even when data is thin — many street dogs will have sparse records early on. "Empty" must feel *hopeful*, never broken.

- **No care logged yet** — a warm, encouraging empty state in the timeline ("The story starts here"), not a cold "No data."
- **Sterilization: Unknown** — a calm, honest treatment (our palette has a dedicated soft "unknown" tone). Never alarming.
- **No assigned clinic / no medications / no medical records** — sections gracefully collapse or show an inviting placeholder; the pass never looks like it has holes punched in it.
- **Long care history** — a timeline that scales (the screen version can scroll; the export may summarize or paginate-in-spirit onto one page — propose how).
- **Very long name / breed / clinic name** — show how type reflows without breaking the layout.
- **Handed-over ward** — a dog whose guardianship was transferred is still fully documented; consider a subtle "care continued by another guardian" note. Never delete a dog's story.
- **Live-photo cover vs. still cover** — screen may animate the live photo subtly; export is always the still frame.

---

## 9. Hard constraints & guardrails (read these carefully)

These are the *only* things holding you back. Within them, go wild.

1. **Honesty — non-negotiable.** The pass is a proudly self-issued caretaker's record. It may look official and premium, but it must **never impersonate a real government, municipal, or veterinary authority** — no fake official seals of real bodies, no forged letterheads, no implied legal authority. The **EST./OBS. provenance system stays**: AI guesses are labeled as guesses. Attribution to DoggoCollector + the guardian's handle is always visible. Credible, yes; counterfeit, never.
2. **Print-safe & grayscale-safe.** Life B must survive a bad printer and losing color. Every luminous effect needs a flat analogue.
3. **Respect Sunny Fetch, but earn the promotion.** Use our palette (§10). The metal/foil is warm gold-and-sun, never cold chrome or neon. It must read as the same family as the app — "different but similar, all at once."
4. **No alarm red, anywhere.** Guardian Mode has a firm rule: nothing about a dog's health or status may read as an emergency. Our injury/attention tints are deliberately soft (muted pink, warm amber). Keep status treatments calm and kind. This is a welfare tool, not a warning label.
5. **Accessibility.** Design the **Reduce Motion** ceremony (graceful, no large motion) and a **Reduce Transparency / Increase Contrast** fallback (the metal field goes to a solid, still, high-contrast warm treatment; the pass stays fully legible). Maintain text contrast in every state. The gorgeous version and the accessible version must *both* feel considered.
6. **Buildable in SwiftUI on iOS 27.** You have Metal shaders (`ShaderLibrary`), `MeshGradient`, `Canvas`, `TimelineView`, CoreMotion parallax, Liquid Glass, `.sensoryFeedback` haptics, and PDF/image rasterization (`ImageRenderer`). Design boldly *within reach of these* — we will implement your vision, so give motion specs, layer breakdowns, and shader intent, not just a flat mock.
7. **One dog per pass.** This is a single dog's credential, not a multi-dog report.

---

## 10. Color & material direction

Use the app's real tokens as the foundation, then extend into metal/foil.

```
Marigold        #F5A623   — primary brand, the "gold" the foil is made of
Marigold Dark   #E08E0B   — pressed/gradient accent, deeper foil
Cream           #FDEFDC   — app background / the paper the pass is printed on
Card White      #FFFFFF   — the document surface
Chip Cream      #F5E8D3   — warm fills
Ink             #2B2013   — primary text / the current header band / deboss
Ink Muted       #8A7A63   — secondary text, labels, eyebrows
Hairline        #DDD5C7   — the pass's fine rules (extend into guilloché line-work)

Guardian status (soft — NO alarm red):
  Done       bg #EAF6E7 / border #CDE8BE / accent #3E8E52   (sterilized / vaccinated)
  Attention  bg #FFF0D8 / border #F0DEBF / accent #D69A3C   (needs attention, gentle)
  Unknown    bg #F1EBE0 / border #E2D6C2                    (calm, honest)

Care-log tints (for the timeline):
  Fed        #FFF0D8 / #E0A21A       Medicated   #EDE6F2 / #7A6A93
  Injury     #FBE0DF / #D66666 (soft pink, NOT red)   Vaccinated  #E2F1DE / #4E9B47

Provenance tags:
  EST.  #F3E4CC / #9A7B45      OBS.  #E6F0E8 / #3E8E52

Callable green (clinic contact): #2FA84F
```

**The foil/metal palette should be built from marigold → marigold-dark → a paler champagne-cream highlight**, with warm iridescent shifts (a whisper of rose-gold and warm green *only* as light-catch accents, never as fills). Think "sunlight on brushed brass," "honey holding light." Propose the exact gradient stops and the iridescent shift you want; we'll shade it.

---

## 11. Typography

- Today the app uses **SF Rounded** everywhere (`.rounded` design), at a scale of: display 34/28 bold, headline 22 bold, body 17, caption 13, eyebrow 12 bold (uppercased, letter-spaced — used for labels like "BREED", "LOGGED CARE HISTORY").
- The brand's intended display/body pairing (Phase 2) is **Baloo 2** (display) + **Nunito Sans** (body) — you may design toward these if it elevates the pass, but note anything that depends on them.
- The pass is a place where **more editorial, more "printed-document" typography** is welcome — a refined all-caps eyebrow system, a strong serialized number style, tabular figures for dates and the serial, tight ledger labels. This is one screen where a touch more typographic formality *helps* sell "credential." Push it — while staying legible and warm.

---

## 12. Motion & haptics principles

- **Continuous, quiet life** in the rest state: the metal field drifts, the foil breathes, nothing is ever fully still — but it's *calm*, meditative, not busy.
- **Tilt = physicality.** The metal catches light with device motion; the foil sweep tracks tilt. This single behavior is what makes it feel real. Prioritize it.
- **Haptics are part of the design.** Spec them: the **seal press** (firm), the **photo drop** (soft), the final **settle** (gentle). Use `.sensoryFeedback`.
- **The ceremony is skippable and once-per-issuance**, not replayed every time the pass opens (opening an existing pass should still *breathe* and be tiltable, but not re-run the full mint).
- **Reduce Motion** = the same dignity via cross-fades and opacity, no large translation or parallax.

---

## 13. Relationship to the rest of the app ("different but similar")

Please explicitly show, in your deliverable, **how the Shelter Pass relates to the existing collection card and the app's chrome** — a small side-by-side or a note. We want a reviewer to look at the pass next to a normal Pack card and *feel* they're siblings (same marigold soul, same Scout, same warmth) while instantly understanding the pass is the *heirloom* of the family — heavier, more permanent, more earned. The current app also just adopted **Liquid Glass** chrome (glass circular controls, glass segmented tabs); the pass's *screen chrome* (close button, Print/Share buttons) should feel at home with that, even as the pass itself is its own precious object.

---

## 14. Deliverables (what we'd love back from you)

1. **The Living Pass** — the full on-screen hero composition (rest state), with the metal-shader field, foil pass, dog photo, seal, and all data laid out. Annotate layers and material intent.
2. **The Issuance Ceremony** — a storyboard / motion sequence (key frames + timing + easing + haptics + Reduce-Motion variant). This is the piece we most want to see thought through.
3. **The Artifact** — the flat, print-safe export layout (single page), annotated with what changes from the screen version (foil→flat, guilloché border, grayscale-safety).
4. **The seal / crest** — the pass's signature Scout-derived emblem, in foil (screen) and flat (print) forms.
5. **States** — no-care-log, unknown sterilization, sparse-data, long-list, and handed-over variants.
6. **The metal-field spec** — gradient stops, iridescent shift, motion behavior, tilt response, and the Reduce-Transparency solid fallback.
7. **Accessibility variants** — Reduce Motion + Reduce Transparency/Increase Contrast versions.
8. **Any new color/material/type tokens** you introduce, named and hex'd, so we can extend our design system cleanly.

Work in your usual interactive HTML/CSS prototype form if that's fastest — motion, shader-feel, and tilt are exactly what we want to *see moving*, not just as stills.

---

## 15. Success criteria (how we'll know you nailed it)

- A caretaker who just pledged their first street dog watches the pass mint itself and **feels proud** — maybe a little emotional.
- Held up next to a real vaccination certificate, ours looks *more* cared-for, not less credible.
- A shelter worker who receives the flat export understands the dog in **ten seconds** and trusts it.
- Someone who sees the screen version says **"how is that a phone screen"** — the metal, the light, the tilt.
- It is unmistakably the same warm app that let them catch the dog in the first place — **different, and similar, all at once.**

Make it the best shelter pass ever made. We mean it.
