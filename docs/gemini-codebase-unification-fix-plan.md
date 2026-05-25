# Tennitus Codebase Unification Fix Plan For Gemini

This document is the single handoff for cleaning the Tennitus codebase into one coherent product architecture. The goal is not to add more features. The goal is to remove mixed agent/provider work, make the app internally consistent, and create a baseline that Codex can review, build, commit, and push.

## Outcome Required

After this pass, the repo should feel like one codebase:

- One user-facing AI feature: comfort-session suggestions from recorded event summaries.
- One client-side API surface for AI calls.
- One backend proxy contract for production AI calls.
- One terminology system: "pattern profile" and "comfort support", not diagnostic "tinnitus subtype" or "therapy prescription".
- One secrets approach: no production API keys in the iOS app.
- One Git-ready baseline: builds cleanly, no generated secrets staged, no AppleDouble `._*` noise staged.

Do not introduce another parallel implementation. Refactor and consolidate.

## Non-Negotiables

1. Do not put API keys in Swift source, Info.plist, generated Swift files, or user-facing app settings for production.
2. Do not send raw audio to an LLM. Send compact numeric features, selected time windows, source-detection labels, and the user's typed description.
3. Do not claim diagnosis, treatment, cure, medical classification, or audiologist-grade calibration.
4. Do not remove the STFT/spectrogram workflow. It is a core feature.
5. Do not remove Apple Health sleep/hearing context. It should be transparent context, not a hidden clinical score.
6. Do not rename broad product concepts in a way that breaks stored portable exports unless migration is included.

## Current Problems To Fix

### 1. AI Provider Mixing

Current state:

- `Tennitus/Services/ChatGPTTherapyAdvisor.swift` directly calls OpenAI.
- `Tennitus/Services/GeminiTherapyAdvisor.swift` directly calls Gemini.
- `Tennitus/Views/LabView.swift` now references Gemini but still says ChatGPT in at least one safety note.
- `Tennitus/Views/SettingsView.swift` still has an "OpenAI POC" section.
- `backend/openai_proxy/main.py` is actually a Gemini proxy.
- `backend/openai_proxy/README.md` still describes an OpenAI proxy.

Required fix:

- Create one app-facing abstraction:
  - Suggested name: `ComfortSessionAdvisor`.
  - It should expose one method, for example:
    `suggestComfortSession(request: ComfortSessionAdvisorRequest) async throws -> ComfortSessionSuggestion`.
  - The SwiftUI views should call this abstraction only.
- Keep provider-specific code behind the abstraction:
  - For local debug only, provider implementations may exist behind `#if DEBUG`.
  - For TestFlight/production, the implementation should call the backend proxy.
- Do not let `LabView`, `EventLoggerView`, or `SettingsView` know whether the backend uses OpenAI, Gemini, or another provider.

Acceptance criteria:

- `rg -n "ChatGPT|Gemini|OpenAI POC|Google Gemini" Tennitus/Views Tennitus/Models` returns no user-facing provider-specific labels except in developer-only debug settings.
- There is one user-facing label such as "AI comfort suggestion" or "Event insight".
- The app still builds.

### 2. Backend Naming And Contract

Current state:

- Backend folder name says `openai_proxy`.
- FastAPI app title says `Tennitus Gemini Proxy`.
- README says OpenAI.
- Request schema is narrower than the iOS app's current analysis payload.

Required fix:

- Rename conceptually to a provider-neutral backend. If moving files is too risky for now, keep the folder but update all visible names and docs to "AI proxy".
- Preferred future path:
  - `backend/ai_proxy/main.py`
  - `backend/ai_proxy/README.md`
- If files are moved, update scripts/docs that reference `backend/openai_proxy`.
- Backend request model must support the app's full numeric event summary:
  - user description
  - background description
  - tinnitus match frequency
  - duration seconds
  - RMS dBFS
  - peak dBFS
  - spectral centroid
  - dominant frequency
  - top frequency peaks
  - dominant band
  - sensitive range
  - band energy
  - target sound matches
  - source detections
  - weighted trigger score
  - Apple Health sleep/hearing context
  - pattern profile
- Backend response should remain `ComfortSessionSuggestion`.

Acceptance criteria:

- README and backend app title agree.
- Backend validates the same payload the iOS app sends.
- Provider selection is controlled server-side by environment variables, not app UI.
- The iOS app has a single backend URL setting for debug/TestFlight if needed.

### 3. Secrets And Key Handling

Current state:

- `Tennitus/Services/OpenAISecrets.generated.swift` contains a real key locally.
- `.gitignore` ignores it, but the local plaintext key still exists and was exposed.
- `OpenAIKeyProvider` is OpenAI-specific but reused for Gemini loading.
- App UI asks for provider API keys.

Required fix:

- Remove the real key from `OpenAISecrets.generated.swift` locally and replace with an empty placeholder.
- Rename `OpenAIKeyProvider` if still needed:
  - Preferred: remove from production path.
  - Debug-only fallback name: `DeveloperAIKeyProvider`.
- Production/TestFlight should call backend proxy. The backend owns provider keys.
- Add a clear developer note:
  - Exposed keys must be rotated.
  - `.env` is for local backend/server execution only, not embedded iOS secrets.

Acceptance criteria:

- `rg -n "sk-|AIza|GEMINI_API_KEY|OPENAI_API_KEY" Tennitus` finds no real secrets.
- TestFlight build does not ask the tester for an OpenAI/Gemini key.
- Debug builds can still use local provider keys only if explicitly gated behind `#if DEBUG`.

### 4. Product Language Cleanup

Current state:

- Model is named `TinnitusSubtype`.
- UI says "Pattern Profile", but code and prompts still use "classified Tinnitus Subtype".
- Gemini prompt says "Since their subtype is...".

Required fix:

- User-facing language must be:
  - "pattern profile"
  - "reported pattern"
  - "sound sensitivity clues"
  - "comfort suggestion"
  - "indicative"
  - "not diagnostic"
- Avoid:
  - "classified subtype"
  - "diagnosed"
  - "treatment"
  - "therapy prescription"
  - "ASHA severity" unless explicitly framed as informal/indicative and not a clinical score.
- Code can keep `TinnitusSubtype` temporarily if renaming would create migration risk, but all prompts and UI must use "pattern profile".

Acceptance criteria:

- `rg -n "classified Tinnitus Subtype|Since their subtype|Active Subtype|diagnose|treat|prescribe" Tennitus backend docs` only returns safety disclaimers or internal code names.
- Reports and PDF exports say "Indicative pattern profile", not "classification".

### 5. Event Logging Must Stay The Primary Flow

Current product decision:

- The user does not want "Lab" as a separate primary feature.
- The home flow should start with "Log event".
- Recording should be the first step/question.
- While the questionnaire continues, recording may continue in the foreground if iOS permissions and UX allow it.

Required fix:

- Keep event logging as the primary path.
- Any STFT, spectrogram, source detection, peak detection, and AI suggestion should attach to an event.
- Lab can remain as a developer/advanced review area only if it does not duplicate or compete with the main flow.

Acceptance criteria:

- From Today/Home, a user can:
  1. tap Log event
  2. start recording
  3. describe the bothersome source
  4. set distress/loudness
  5. review STFT/spectrum/audio features
  6. save event
  7. optionally request AI comfort suggestion
- Saved event includes the selected STFT frame/time window and audio feature summary.

### 6. STFT And Graph Interaction Must Be Preserved

Current required feature:

- User should be able to slide through audio.
- Tapping the colored frequency-vs-time spectrogram should jump to that recording frame.
- The dB-vs-frequency graph should update to the selected STFT frame.
- Tapping graph points should show frequency, dBFS, and time window values.

Required fix:

- Do not simplify spectrogram back to static bars.
- Keep 0.5s STFT snapshots, or make frame duration a clearly named constant.
- Optimize rendering instead of removing interaction.
- If zoom crashes, clamp sample counts and render decimated waveform data.

Acceptance criteria:

- Tapping/dragging spectrogram updates:
  - highlighted waveform section
  - selected time label
  - dB-vs-frequency curve
  - selected point readout
- No crash when zooming on recordings up to at least 60 seconds.
- UI explains the spectrogram in one compact side/below note:
  - x-axis = time
  - y-axis = frequency
  - color = relative energy

### 7. Hearing/Audiogram Correctness

Current issue:

- Apple Health displayed 1 dBHL left and 10 dBHL right, while the app previously pulled/averaged values as approximately 0 and 12.
- The intended correction is PTA-style averaging over 500, 1k, 2k, and 4k when enough data exists.

Required fix:

- Keep Apple Health summary transparent:
  - latest sample date
  - source name
  - left PTA average
  - right PTA average
  - frequencies used in average
  - number of points read
- Do not pretend this is a new hearing test unless the user explicitly runs the app's indicative tone test.

Acceptance criteria:

- Health section shows values close to Apple Health summary when the same PTA frequencies exist.
- Detailed view shows which points were included.
- Audiogram save flow has an explicit warning before writing app-generated thresholds to Apple Health.

### 8. Red Flags And Safety

Current state:

- Red flag screening exists in Settings.
- Classifier returns unknown when red flags are present.

Required fix:

- Keep red flag screening, but make it visible at the right moment:
  - onboarding/profile
  - settings
  - before interpreting pattern profile if red flags are active
- Severe distress and sudden one-sided hearing changes should trigger "seek medical support" copy.
- Do not block normal logging, but avoid generating confident comfort suggestions when red flags are active.

Acceptance criteria:

- Pattern profile card shows a medical-review note when red flags exist.
- AI prompt includes red flag status if present.
- AI response is conservative when red flags exist.

## Target Architecture

Use this structure:

```text
Tennitus/
  Models/
    TinnitusModels.swift
    LabModels.swift
    AudiogramModels.swift
  Services/
    ComfortSessionAdvisor.swift          # app-facing protocol/client
    BackendComfortSessionAdvisor.swift   # production/TestFlight client
    DebugDirectAIAdvisor.swift            # optional DEBUG-only provider caller
    SpectrumAnalyzer.swift
    SoundSourceDetectionService.swift
    TriggerWeightingEngine.swift
    AppleHealthContextReader.swift
    PortableDataExportService.swift
  Views/
    EventLoggerView.swift
    AudioVisualViews.swift
    TodayView.swift
    SettingsView.swift
backend/
  ai_proxy/
    main.py
    README.md
```

If moving backend folders is too risky in one pass, keep the existing folder path but apply the same provider-neutral naming inside code/docs.

## Suggested Implementation Order

1. Create `ComfortSessionAdvisor.swift`.
2. Move shared request/response payload mapping into that file or a small mapper service.
3. Update `LabView` and event flow to call `ComfortSessionAdvisor`, not Gemini/OpenAI directly.
4. Update Settings so users are not asked for provider API keys in TestFlight/production.
5. Make backend provider-neutral and update README.
6. Update backend schema to accept the full iOS payload.
7. Replace user-facing "ChatGPT", "Gemini", "OpenAI POC", and "subtype classification" language.
8. Verify STFT interactions still work after refactor.
9. Verify Apple Health hearing summary still uses the corrected PTA-style average.
10. Run build and lightweight checks.

## Checks Gemini Must Run Before Handing Back

Run these from repo root:

```bash
rg -n "sk-|AIza" Tennitus backend docs
rg -n "ChatGPT|Gemini|OpenAI POC|Google Gemini" Tennitus/Views Tennitus/Models
rg -n "classified Tinnitus Subtype|Since their subtype|Active Subtype" Tennitus backend docs
plutil -lint Tennitus.xcodeproj/project.pbxproj Tennitus/Tennitus.entitlements
swiftc -parse Tennitus/Models/TinnitusModels.swift Tennitus/Services/TinnitusSubtypeClassifier.swift Tennitus/Views/TodayView.swift Tennitus/Views/SettingsView.swift
```

If Gemini can run Xcode locally, also run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Tennitus.xcodeproj \
  -scheme Tennitus \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/TennitusGeminiBuild \
  build
```

If Gemini cannot run the full build, it must clearly say that in the handoff.

## What Gemini Should Not Do

- Do not add another AI provider UI.
- Do not add a new separate "AI Lab" feature.
- Do not remove existing event logs/export compatibility.
- Do not commit `.env`, `.p8`, `private/`, generated secret files, DerivedData, or AppleDouble `._*` files.
- Do not change bundle identifiers, signing team, provisioning, or TestFlight upload scripts unless explicitly asked.
- Do not claim the app identifies the user's tinnitus type from microphone audio. The app can infer a self-reported pattern profile from questionnaires, tone matching, and contextual data.

## Handoff Back To Codex

When Gemini is done, hand back:

1. Summary of files changed.
2. Exact behavior changed.
3. Commands run and whether they passed.
4. Any full Xcode build error output if build fails.
5. Remaining risks.

Then Codex should:

1. Review the diff.
2. Run full Xcode build.
3. Fix regressions.
4. Create the first clean Git baseline commit.
5. Push to GitHub after review is accepted.

## Recommended Gemini Prompt

Use this exact prompt:

```text
You are working in the Tennitus native SwiftUI iOS repo. Follow docs/gemini-codebase-unification-fix-plan.md exactly.

Goal: unify the codebase into one coherent AI/event-analysis architecture. Do not add a new feature branch of behavior. Remove provider-specific UI mixing and create a provider-neutral ComfortSessionAdvisor path.

Constraints:
- No production API keys in the iOS app.
- No raw audio sent to LLMs.
- Preserve STFT/spectrogram/audio event analysis.
- Preserve Apple Health sleep/hearing context.
- Use "pattern profile" and "comfort suggestion", not diagnostic subtype language.
- Do not change signing, bundle IDs, TestFlight scripts, or provisioning.
- Do not stage or commit anything.

Deliver:
- Implement the refactor.
- Update backend/docs naming and schema.
- Run the checks listed in the document.
- Give a concise handoff with changed files, commands run, pass/fail, and remaining risks.
```

## Final Product Direction

Yes, we can make this a single codebase. The rule is: Gemini can implement focused changes, but Codex owns review, build verification, Git hygiene, and pushing. That avoids two agents making overlapping architectural decisions.

Use Gemini for scoped implementation work. Use Codex as the maintainer gate.
