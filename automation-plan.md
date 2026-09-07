# Automation plan

This is the sprint-planning-style companion to "A Dream of Automation" in [episode-pipeline.md](episode-pipeline.md): a rough breakdown of what it actually takes to get from today's manual/scripted pipeline to the one-app version described there. It's not an exhaustive spec, just epics, rough tasks, and gut-check estimates to get the project moving.

**Scope note:** per episode-pipeline.md, two things stay manual on purpose and are *not* part of this plan: **Transcription/Verification** (the text pipeline is deliberately human-supervised) and **Guest reader onboarding** (avatars, readers.csv entries — explicitly called out as staying manual "until after the Dream of Automation is realized"). This plan covers everything from "sentence is ready to record" through "episode is live and scheduled."

## Assumptions (call these out early, adjust as needed)

- Solo, hobby-pace effort — no prior iOS or mobile dev experience, roughly 5-8 hrs/week.
- Target is personal use on your own iPhone, not an App Store release — cheapest, fastest path to "it runs on my phone."
- "Vibecoding" the app means AI-assisted coding (Claude Code or similar) against a real toolchain (Xcode), not a no-code app builder.

## Epics

### Epic 0 — Foundations
Get to "I can build and run something on my own phone" before building anything real.
- Apple dev account: a free Apple ID + Xcode can sideload to your own device already, rebuilding every ~7 days; the paid Apple Developer Program ($99/yr) removes that limit and unlocks TestFlight if you ever want it on more than one device. Start free, upgrade only if the 7-day rebuild becomes annoying.
- Install Xcode on the Macbook, get a "hello world" SwiftUI app running on your phone via a cable/local network build.
- Decide build approach: native SwiftUI (recommended — direct access to AVFoundation for recording/trimming, simplest personal-device install) vs. a cross-platform framework. Default to native unless a specific blocker shows up.
- **Estimate:** 1-2 weekends (S)

### Epic 1 — Data & sequencing engine
Give the app the same "what's next" knowledge the manual process has today.
- Decide where the app's source of truth lives: a synced copy of `text/`, `readers.csv`, `config.yml` pulled from GitHub on launch, vs. bundling a snapshot and updating it by hand.
- Port the "Picking the next sentence" logic (episode-pipeline.md) — next `text/` entry without a matching `audio/` file.
- Decide how the app knows what's already *published* (not just recorded) — scan local state vs. query Buzzsprout's episode list.
- **Estimate:** ~1 week (M) — first real unknown-heavy epic.

### Epic 2 — Recording & local audio processing
The biggest chunk of actual engineering, mirroring "Recording" and "Editing" in episode-pipeline.md.
- Record screen: big-font sentence display, scroll a few sentences ahead/behind, record button, multiple takes, pick-a-take.
- Auto-trim: silence detection at head/tail (AVFoundation/Accelerate, or a simple energy-threshold trim).
- Auto noise-reduction: research options (Apple's built-in voice isolation vs. a DSP approach) — this is roughly reproducing what Voice Memo's "Studio Voice" already does, and is the riskiest audio unknown.
- Export format: iOS has no native MP3 *encoder*. Either bundle one (e.g. LAME) or standardize the whole pipeline on AAC/M4A instead (Voice Memo already produces these) — worth deciding early since it touches filenames and Buzzsprout uploads too.
- **Estimate:** 2-3 weeks (L)

### Epic 3 — Metadata generation
Mostly porting existing, well-understood logic (`credit.rb`) rather than inventing anything new.
- Reimplement the `config.yml` + `readers.csv` → title/description template logic on-device.
- Guest-reader picker in the recording flow (defaults to you) that reads existing `readers.csv` entries — does *not* include onboarding a new guest, which stays the separate manual process.
- Auto-filename via the `$PART.$CHAPTER.$SENTENCE` convention.
- **Estimate:** 2-4 days (S/M)

### Epic 4 — Buzzsprout integration
The single biggest *external* unknown in the whole plan — do this spike early, before sinking time into Epic 2's polish.
- Spike: read Buzzsprout's API docs and confirm it actually supports programmatic upload, title/description, and **scheduled** publish date/time (not just immediate publish). This one finding can reshape the rest of the plan.
- Get API credentials, do one full manual upload via curl/Postman before writing any app code against it.
- Build the in-app upload/schedule client.
- **Estimate:** spike 1-2 days, full integration 3-5 days (M)

### Epic 5 — End-to-end flow & polish
- Wire Epics 1-4 into the single-tap flow from "A Dream of Automation": present → record → auto-trim/denoise → save → upload → title/describe → schedule → confirm.
- Add the "final authorization" review-before-publish step the doc calls for.
- Error handling/retry for live network calls — this flow now depends on APIs instead of a browser you're driving by hand.
- **Estimate:** ~1 week (M)

### Epic 6 — Stretch goals (not required for MVP)
- Automate the git commit/push of `audio/` + `descriptions/` + `text/` so the GitHub backup doesn't require the Macbook.
- In-app guest onboarding (avatar capture, `readers.csv` entry) — deliberately deferred, see Scope note above.
- Self-hosting exploration (Castopod / bespoke RSS+site) — tracked separately under "Future changes" in episode-pipeline.md; orthogonal to this app and non-blocking.

## Rough total estimate

Epics 0-5 (the MVP): roughly **6-8 weeks of elapsed time** at hobby pace (5-8 hrs/week). Epic 4's Buzzsprout spike is the make-or-break unknown — if the API can't do scheduled publish, Epics 4 and 5 both grow, and Epic 6's self-hosting stretch goal becomes worth pulling forward.

## Suggested order of attack

1. **Buzzsprout API spike (Epic 4)** — de-risk the biggest unknown before investing in app plumbing.
2. **Epic 0** — foundations.
3. **Epic 1** — data/sequencing, can overlap with Epic 0 once the basics are up.
4. **Epic 3** — metadata generation; small, and gives you real data to test Epic 4 against.
5. **Epic 2** — recording/audio processing, the biggest single chunk.
6. **Epic 4** — full integration (spike already done in step 1).
7. **Epic 5** — glue + polish.
8. **Epic 6** — stretch, opportunistic.

## Open questions to resolve early

- Personal-device-only install, or eventually shared with guest readers too? (Changes whether the paid Apple Developer Program / TestFlight is needed sooner.)
- Keep MP3 as the target format, or standardize on AAC/M4A to sidestep needing an MP3 encoder on iOS?
- Does Buzzsprout's API actually support a scheduled publish date, or only immediate publish?
