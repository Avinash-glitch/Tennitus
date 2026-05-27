# Gemini Implementation Plan: Tinnitus App Review Changes

Source review document: `Tinnitus App Review.docx`, dated 26 May 2026.

This plan converts the review into implementation tasks for the native SwiftUI Tennitus app. The goal is to address the five UI/UX issues without introducing a second design language or breaking the existing audio/STFT/event logging work.

## Current Code Context

Important files:

- `Tennitus/Views/TodayView.swift`
  - Home screen.
  - The main `Log event` button currently presents `LabView` using `fullScreenCover`.
- `Tennitus/Views/LabView.swift`
  - Advanced lab flow with tone match, recording, spectrum review, and AI proxy suggestion.
- `Tennitus/Views/EventLoggerView.swift`
  - Dedicated dark event logging flow.
  - Already has record/distress/loudness/context/spectrum/review steps.
  - Recently changed so recording can continue while the questionnaire is completed.
- `Tennitus/Views/AudioVisualViews.swift`
  - Waveform, spectrogram, and spectrum interaction components.
- `Tennitus/Services/SpectrumAnalyzer.swift`
  - Local FFT/STFT analysis and target-sound matching.
- `Tennitus/Services/SoundSourceDetectionService.swift`
  - On-device Apple SoundAnalysis classifier path.
- `Tennitus/Services/AppleHealthContextReader.swift`
  - Currently fetches Apple Health sleep summary and latest audiogram summary only.
- `Tennitus/Models/TinnitusModels.swift`
  - `AppleHealthContext`, `AppleSleepSummary`, and `AppleHearingSummary` currently store only aggregate fields.
- `Tennitus/Views/SettingsView.swift`
  - Apple Health sync UI currently shows only summary values.

Critical product decision before coding:

- Make `EventLoggerView` the primary `Log event` flow, or deliberately keep `LabView` as the primary flow and fix all review issues there.
- Recommended: make `EventLoggerView` the primary Home `Log event` destination and keep `LabView` as an advanced/secondary lab tool. The review language refers to a linear log-event flow, which matches `EventLoggerView` better than `LabView`.

Do not remove `LabView` in this pass.

## Global Rules

1. Keep the app pure native SwiftUI.
2. Preserve the dark event logger visual style.
3. Preserve STFT/spectrogram and graph interactions.
4. Do not add provider API keys to the app.
5. Do not send raw audio to an LLM.
6. Keep AI/source identification local or backend-proxy based, with clear failure UI.
7. Do not change signing, bundle identifier, TestFlight scripts, or provisioning.
8. Run full Xcode build before handoff.

## Issue 01: Home Log Event Button Styling

Review issue:

- The Home `Log event` button feels dull/generic and should have a premium translucent/glassmorphism treatment.

Current code:

- `Tennitus/Views/TodayView.swift`
- The button is a plain `Button` with a solid primary circle.

Required implementation:

1. Create a small reusable component in `TodayView.swift`, for example:
   - `LogEventGlassButton`
2. Replace the current solid button body with a glass-style control:
   - translucent background
   - subtle material blur if compatible with the current design
   - soft border/inner highlight
   - shadow using `TennitusStyle.primary` and/or `TennitusStyle.accent`
   - no grey fill
3. Keep text readable on light background.
4. Keep the tappable area large and stable.
5. Use native SwiftUI materials, gradients, and overlays. Do not use custom image assets for this.

Suggested visual approach:

```swift
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(
            LinearGradient(colors: [
                .white.opacity(0.75),
                TennitusStyle.primary.opacity(0.35),
                TennitusStyle.accent.opacity(0.25)
            ], startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1
        )
)
.shadow(color: TennitusStyle.primary.opacity(0.18), radius: 22, x: 0, y: 14)
```

Acceptance criteria:

- Home button no longer reads as flat grey.
- Button still clearly says `Log event`.
- Button still opens the intended log-event flow.
- Works on small iPhone width without text clipping.

## Issue 02: Log Event Page Missing Back Navigation

Review issue:

- User is trapped after tapping `Log event`.
- Need sticky iOS-style back navigation.

Current risk:

- `TodayView` currently presents `LabView`, not `EventLoggerView`.
- `EventLoggerView` currently has an `xmark` button, not a chevron-left `Back` label.
- `LabView` has internal back headers for subroutes, but needs a reliable top-level dismiss.

Required implementation:

1. Decide primary route:
   - Recommended change in `TodayView.swift`:
     ```swift
     .fullScreenCover(isPresented: $showingEventLogger) {
         EventLoggerView()
             .environmentObject(store)
     }
     ```
   - Keep `LabView` reachable elsewhere only if there is already a sensible route. Do not remove it.
2. Update `EventLoggerView.header`:
   - Replace the standalone `xmark` circle with an iOS-style top-left back button:
     - `chevron.left`
     - label `Back`
   - Keep it sticky because the header is outside step content.
3. Add unsaved-data handling:
   - Track whether there is unsaved data:
     - active recording
     - completed recording
     - non-default distress/loudness
     - non-empty context/notes
     - selected triggers
   - If no unsaved data, dismiss immediately.
   - If unsaved data exists, show confirmation:
     - title: `Discard log?`
     - message: `This will stop recording and discard this unsaved event.`
     - buttons: `Keep editing`, `Discard`
   - On discard, stop recorder and dismiss.

Acceptance criteria:

- Log event page always has a visible Back control.
- Tapping Back returns to Home.
- If data exists, user gets confirmation before losing it.
- Active recording stops when discarding.
- Entered values are not lost unless the user confirms discard.

## Issue 03: Match Page Lower/Upper Edge Tap Behaviour

Review issue:

- Tapping lower/upper screen edges triggers a match-page action.
- Need to clarify whether this is intentional or remove it.

Required investigation:

1. Search for gesture handlers in these files:
   - `Tennitus/Views/LabView.swift`
   - `Tennitus/Views/EventLoggerView.swift`
   - `Tennitus/Views/AudioVisualViews.swift`
   - `Tennitus/Views/AudiogramView.swift`
2. Specifically inspect:
   - `.onTapGesture`
   - `.gesture`
   - `DragGesture`
   - `.contentShape`
   - invisible overlays
   - full-screen `GeometryReader` tap areas
   - sliders with oversized frames
3. Determine whether the edge tap is:
   - waveform selection
   - STFT/spectrogram tap-to-select
   - slider hit area
   - accidental full-screen tap target
   - navigation/route shortcut

Required implementation:

- If accidental:
  - Remove the full-screen/edge gesture.
  - Restrict tap gestures to the visible waveform/spectrum/spectrogram control bounds only.
- If intentional:
  - Add a short code comment next to the gesture explaining why it exists.
  - Add a one-time user-facing hint only if the gesture is genuinely important.

Acceptance criteria:

- Tapping blank top/bottom edges does not unexpectedly trigger match-page actions.
- Tapping inside actual waveform/spectrum controls still works.
- Any retained gesture has an explanatory code comment.

## Issue 04: AI Sound Identification Not Working

Review issue:

- The feature that uses the user's sound description to identify the relevant sound element is not returning results.

Current implementation likely has two paths:

- Local target matching:
  - `SpectrumAnalyzer.analyzeTargeted(...)`
  - Produces `targetSoundMatches`, for example electric-guitar-like, sibilance-like, sharp high-frequency.
- On-device classifier:
  - `SoundSourceDetectionService.detect(audioFileURL:userDescription:)`
  - Uses Apple SoundAnalysis when available.

Known fragile point:

- Identification requires a saved audio file URL. If the recording has not been finalized/written before detection runs, source detection can silently return nothing.
- `EventLoggerView.detectDescribedSource()` only runs when moving to review and requires:
  - `recordingResult?.audioFileURL`
  - non-empty `targetDescription`
  - `!isDetectingSource`

Required debugging steps:

1. Confirm which screen is being used as the primary flow:
   - `EventLoggerView`
   - `LabView`
2. Add debug logging in DEBUG builds only:
   - input description
   - whether audio URL exists
   - whether file exists on disk
   - number of local target matches
   - number of SoundAnalysis detections
   - any thrown SoundAnalysis errors
3. Ensure detection is called after recording is finalized and audio file is written.
4. Ensure local target matching always runs, even when SoundAnalysis returns no labels.
5. Ensure UI has clear states:
   - `Analysing described sound...`
   - `Matched described sound`
   - `No confident source label found; showing frequency clues instead`
   - error fallback if classifier fails
6. Do not depend on Gemini/OpenAI for this feature.
   - The app should locally use the user's typed description as a hint over spectral features.
   - AI proxy can summarize later, but should not be required for basic identification.

Required implementation:

- In `EventLoggerView`:
  - Make sure `finalizeRecording()` runs before `detectDescribedSource()`.
  - Re-run `detectDescribedSource()` after `reanalyseSelectedSegment()` if a description exists.
  - Surface `targetSoundMatches` even when `sourceDetections` is empty.
- In `SpectrumAnalyzer`:
  - Confirm target phrase mapping covers:
    - electric guitar
    - guitar
    - music
    - voice
    - sibilance
    - hiss
    - squeal
    - alarm
    - fan
    - low hum
  - If needed, add phrase aliases, but keep it deterministic and transparent.
- In `SoundSourceDetectionService`:
  - Add DEBUG-only error logs.
  - Return an empty list with a reason surfaced to UI if classifier is unavailable.

Acceptance criteria:

- With a recording and description `electric guitar in the music`, the review screen shows either:
  - a target match card from local spectrum matching, or
  - a fallback saying no classifier label was found but local frequency clues are available.
- No silent failure.
- No raw audio sent to the AI proxy.
- Build succeeds.

## Issue 05: Full Apple Health / Hearing Data View

Review issue:

- Current Apple Health section only shows aggregate/average data.
- User wants every individual point, timestamp, value, and source.

Current code:

- `AppleHealthContextReader.fetchSleepSummary(...)` only returns summary.
- `AppleHealthContextReader.fetchLatestAudiogramSummary()` only returns latest audiogram summary.
- `AppleHealthContext` only stores `sleep` and `hearing` summaries.
- `SettingsView` only shows summary text.

Required data model additions:

Add Codable models in `Tennitus/Models/TinnitusModels.swift`:

```swift
struct AppleHealthDataPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: Kind
    var startDate: Date
    var endDate: Date?
    var value: Double
    var unit: String
    var sourceName: String?
    var metadata: [String: String] = [:]

    enum Kind: String, Codable, CaseIterable {
        case sleepSegment
        case audiogramLeft
        case audiogramRight
    }
}
```

Extend `AppleHealthContext`:

```swift
var dataPoints: [AppleHealthDataPoint] = []
```

Preserve Codable compatibility:

- Add default value.
- If custom decoding exists, make missing `dataPoints` decode as `[]`.

Required HealthKit reader changes:

- In `AppleHealthContextReader.syncContext(...)`:
  - Fetch sleep segment data points for the lookback range.
  - Fetch audiogram point data for at least the latest sample, preferably all relevant samples if reasonable.
  - Store every point with source name and timestamp.
- For sleep:
  - one data point per asleep segment
  - value = duration hours
  - unit = `hours`
  - sourceName = sample source
  - metadata can include sleep stage if available
- For audiogram:
  - one point per frequency/ear threshold
  - value = dB HL
  - unit = `dB HL`
  - metadata:
    - `frequency_hz`
    - `ear`
    - `sample_date`

Required UI changes:

1. In `SettingsView`, Apple Health card:
   - Keep existing summary.
   - Add a `View full history` or `See all health data` button.
2. Create a new SwiftUI view:
   - suggested file: `Tennitus/Views/AppleHealthHistoryView.swift`
   - title: `All Health Data`
   - sections or filter segmented control:
     - `All`
     - `Sleep`
     - `Hearing`
   - sorted descending by date.
3. Row display:
   - timestamp
   - source
   - value and unit
   - metadata summary, e.g. `Left · 4 kHz`, `REM sleep`, etc.
4. Empty state:
   - `Sync Apple Health to see detailed points.`

Acceptance criteria:

- Settings still shows summary.
- User can open a full history page.
- Full history displays individual sleep and audiogram points.
- List is date-descending.
- No HealthKit permission regression.
- Existing exported/stored data remains decodable.

## Suggested Implementation Order

1. Switch/confirm Home `Log event` route to `EventLoggerView`.
2. Fix back navigation and unsaved confirmation.
3. Restyle Home `Log event` button.
4. Audit/remove accidental edge tap behavior.
5. Debug/fix sound identification pipeline.
6. Add HealthKit detailed data models and reader support.
7. Add Health history page.
8. Run full Xcode build.

## Required Checks Before Handoff

Run:

```bash
plutil -lint Tennitus.xcodeproj/project.pbxproj Tennitus/Tennitus.entitlements
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Tennitus.xcodeproj \
  -scheme Tennitus \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/TennitusGeminiReviewBuild \
  build
```

Also run targeted searches:

```bash
rg -n "Log event|fullScreenCover|EventLoggerView|LabView" Tennitus/Views/TodayView.swift
rg -n "onTapGesture|DragGesture|contentShape|gesture" Tennitus/Views/LabView.swift Tennitus/Views/EventLoggerView.swift Tennitus/Views/AudioVisualViews.swift
rg -n "targetSoundMatches|sourceDetections|detectDescribedSource|SoundSourceDetectionService" Tennitus
rg -n "AppleHealthDataPoint|dataPoints|All Health Data|Hearing History" Tennitus
```

## Gemini Handoff Format

When done, report:

1. Files changed.
2. Which flow Home `Log event` now opens.
3. What edge gesture was found and what was changed.
4. How AI/source identification was fixed.
5. What exact HealthKit data points are now stored and displayed.
6. Commands run and pass/fail.
7. Remaining risks.

## Prompt To Give Gemini

```text
Implement the UI/UX review changes in docs/gemini-ui-ux-review-change-plan.md.

Constraints:
- Native SwiftUI only.
- Keep EventLoggerView as the primary Log Event flow unless you find a strong reason not to; document that reason.
- Preserve STFT/spectrogram interactions.
- Do not add AI provider keys to the app.
- Do not send raw audio to LLMs.
- Add full HealthKit data history without removing the existing summary.
- Run the required checks and full Xcode build before handing back.
- Do not commit or push.

Return a concise handoff with files changed, behavior changed, checks run, and remaining risks.
```
