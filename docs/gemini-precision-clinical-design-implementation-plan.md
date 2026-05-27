# Gemini Implementation Plan: Precision Clinical Design Refresh

## Goal

Implement the visual design in `tennitus-design/` exactly as a native SwiftUI redesign of the existing Tennitus iOS app. Do not embed React, WebView, Tailwind, or prototype code. Treat the React files as a visual/spec reference only.

The target look is:
- Dark-first clinical interface.
- Near-black blue-tinted background.
- Cyan accent for active/positive states.
- Amber warning for elevated distress.
- Mono numerics for telemetry.
- Glass cards with subtle borders.
- Compact bottom navigation with active dots.
- Animated spectrum bars.
- Skeuomorphic rotary dials for subjective values and tone frequency.

Preserve existing app logic, storage, HealthKit integration, audio recording, spectrum analysis, event logging, tone generation, AI proxy calls, and export behavior.

## Reference Files

Use these prototype files as the design source:

- `tennitus-design/styles.css`: global design tokens, dark palette, glass, grain, dial skin, animation behavior.
- `tennitus-design/MobileFrame.tsx`: dark screen container, subtle radial glow overlays, status text style.
- `tennitus-design/BottomNav.tsx`: compact bottom nav with mono uppercase labels and dot active state.
- `tennitus-design/RotaryDial.tsx`: rotary dial behavior and visual treatment.
- `tennitus-design/SpectrumAnalyzer.tsx`: animated analyzer bars.
- `tennitus-design/routes/index.tsx`: Today dashboard layout.
- `tennitus-design/routes/logger.tsx`: event logger / live recording layout.
- `tennitus-design/routes/lab.tsx`: tone match lab layout.
- `tennitus-design/routes/settings.tsx`: profile/settings layout.

Ignore `._*` AppleDouble files in `tennitus-design/`.

## Non-Negotiable Constraints

1. Keep this a pure native SwiftUI iOS app.
2. Do not remove current functional features.
3. Do not reintroduce direct OpenAI/Gemini API key fields in the client.
4. Do not store secrets in the repo.
5. Do not change HealthKit permissions unless required by a visible feature.
6. Do not change bundle id, signing settings, or deployment target.
7. Keep all changes buildable in Xcode with the existing `Tennitus` scheme.
8. Avoid large rewrites of services. This is primarily a UI system migration.

## Phase 1: Design System Foundation

### Files

- `Tennitus/Views/DesignSystem.swift`
- `Tennitus/Views/ContentView.swift`

### Required Changes

Replace the current light palette with a dark clinical palette equivalent to `styles.css`.

Suggested SwiftUI tokens:

```swift
enum TennitusStyle {
    static let background = Color(red: 0.075, green: 0.078, blue: 0.090)
    static let surface = Color.white.opacity(0.035)
    static let surface2 = Color.white.opacity(0.075)
    static let surfaceElevated = Color(red: 0.145, green: 0.149, blue: 0.168)
    static let primary = Color(red: 0.980, green: 0.984, blue: 0.992)
    static let accent = Color(red: 0.400, green: 0.890, blue: 0.890)
    static let warning = Color(red: 0.950, green: 0.670, blue: 0.250)
    static let destructive = Color(red: 0.920, green: 0.250, blue: 0.190)
    static let graphite = Color(red: 0.970, green: 0.975, blue: 0.985)
    static let muted = Color(red: 0.560, green: 0.585, blue: 0.630)
    static let border = Color.white.opacity(0.08)
}
```

Update:

- `AppScreen` to use `.preferredColorScheme(.dark)`.
- `AppScreen` to add subtle top-right cyan and bottom-left amber radial glow overlays.
- `AppHeader` typography to match the prototype:
  - Eyebrow: 10-11 pt, monospaced, uppercase, high tracking, cyan or muted.
  - Title: bold 28-32 pt.
  - Subtitle: 14 pt muted.
- `AppCard` to become a glass card:
  - dark translucent fill,
  - 1 px white/low-opacity border,
  - 24 px corner radius for main cards,
  - minimal dark shadow,
  - no bright white card backgrounds.
- `AppButtonStyle`:
  - primary: white foreground text on near-white fill, dark label if needed, or cyan fill for high-attention actions depending on screen.
  - secondary: dark glass with border.
  - danger: red/destructive.
- Use `.monospacedDigit()` for every measurement: Hz, dB, scores, counts, duration.

### New Components To Add

Add these native SwiftUI components to `DesignSystem.swift` or split them into small files under `Tennitus/Views/Components/`:

1. `ClinicalStatusBar`
   - Optional left and right strings/views.
   - Small mono uppercase style.
   - Used inside app screens where relevant, not the real iOS status bar.

2. `GlassPanel`
   - Reusable glass surface modifier or view.
   - Same card styling across Today, Logger, Lab, Settings.

3. `ClinicalBottomNav`
   - Replaces default `TabView` tab bar visually.
   - Matches `BottomNav.tsx`: sticky bottom glass bar, active dot, uppercase mono labels.
   - Must preserve navigation to Today, Trends, Sounds/Lab/Reports/Settings as needed.

4. `AnimatedSpectrumBars`
   - Native equivalent of `SpectrumAnalyzer.tsx`.
   - Pure UI animation only, not tied to audio engine unless live analysis data is already available.
   - 24-32 bars, cyan, varying heights, pulsing/scale animation.

5. `RotaryDialControl`
   - Native SwiftUI rotary dial based on `RotaryDial.tsx`.
   - Supports value binding, min/max/step/unit/format.
   - Drag vertically to change value.
   - Optional left/right/up/down accessibility adjustment.
   - Conic/progress ring equivalent using `Canvas`, `AngularGradient`, or custom `Shape`.
   - Tick marks around dial.
   - Center value with mono font.

## Phase 2: Navigation Shell

### Files

- `Tennitus/Views/ContentView.swift`
- Any new navigation shell file if needed.

### Required Changes

The React prototype has four tabs:

- Today
- Logger
- Lab
- Profile

The current app has:

- Today
- Trends
- Sounds
- Reports
- Settings

Do not remove existing product areas. Recommended native mapping:

- Keep five product tabs if needed, but restyle them to the compact glass bottom nav.
- Labels should be short and mono uppercase:
  - Today
  - Trends
  - Sounds
  - Reports
  - Profile
- If adding a Logger tab, do not duplicate Today's main Log Event CTA. Prefer keeping Logger as a modal/full-screen flow launched from Today unless Avinash explicitly requests a permanent Logger tab.

Acceptance:

- The default iOS white tab bar must not appear.
- Bottom nav should visually match `BottomNav.tsx`: rounded glass pill, active cyan dot, inactive dark dots, mono uppercase labels.
- Safe area must be respected on iPhone.

## Phase 3: Today Dashboard Redesign

### File

- `Tennitus/Views/TodayView.swift`

### Target From Prototype

Use `tennitus-design/routes/index.tsx`.

### Required Layout

1. Header:
   - Eyebrow: `PROFILE · <subtype or profile label> · <date>`
   - Title: `Today's Pulse.`
   - Dark background, cyan eyebrow.

2. Primary status card:
   - Glass rounded card.
   - Left: Distress Level as two-digit mono number, `/10`.
   - Right: Peak Hz from saved tone match or latest analysis.
   - Small bar visualization below.
   - One-line summary from `store.weeklyInsight.headline` or latest event.

3. 7-day history:
   - Bar chart style from prototype.
   - Today bar cyan, previous bars cyan opacity.
   - Trend label top right.
   - Use actual check-in/event data if available; otherwise use empty state, not fake hardcoded values.

4. Quick actions:
   - Glass tiles:
     - `Log Event`: opens `EventLoggerView`.
     - `Tone Match`: opens `LabView` or navigates to Lab tab.
   - Use compact icon/label structure from prototype.

5. Recent activity:
   - List recent events/spikes.
   - Glass rows.
   - Include environment/context, note, time, severity.

Move older long-form sections lower or behind secondary routes:

- Pattern Profile
- Health Context
- Trigger Weighting
- Daily Check-in
- Spike Support

Do not delete them. The Today screen should feel like the prototype first, not a long settings/report page.

Acceptance:

- First viewport must show header + status card + some trend/quick action content.
- No light cards.
- No white text on white background.
- Real app data preferred over prototype dummy values.

## Phase 4: Event Logger Redesign

### File

- `Tennitus/Views/EventLoggerView.swift`

### Target From Prototype

Use `tennitus-design/routes/logger.tsx`.

### Required Behavior To Preserve

- User can start recording.
- Recording can remain active while completing the questionnaire.
- User can enter target sound description.
- User can choose context tags.
- Audio analysis results are saved into the event.
- Unsaved back/discard behavior remains.
- STFT/spectrum references must not disappear.

### Required Visual Layout

Use a dark full-screen flow.

Top area:

- Small mono status left:
  - `● REC ACTIVE` in cyan while recording.
  - `READY` or `REC SAVED` otherwise.
- Status right:
  - peak frequency if known, otherwise duration.

Header:

- Eyebrow: `CAPTURE · STEP X OF Y`
- Title should match current step but in dark style.
- Subtitle should be concise.

Recording/spectrum card:

- Use `AnimatedSpectrumBars` for live/recording state.
- Below bars, show:
  - Ambient pressure / peak dBFS or approximate dB if available.
  - Peak frequency.
- Use real analysis values when present.

Subjective readings:

- Replace ordinary sliders for loudness and distress with `RotaryDialControl`.
- Loudness uses cyan accent.
- Distress uses amber warning accent.
- Keep the current values 0-10 and persistence unchanged.

Context:

- Tags should become mono uppercase pills like `#OFFICE`, `#LOW_SLEEP`, `#HEADPHONES`.
- Selected: cyan translucent fill + cyan border.
- Unselected: dark surface + muted label.

Save:

- Full-width rounded primary action matching prototype.
- Text: `SAVE DATA ENTRY` or app's current wording.

Spectrum/STFT:

- Keep current STFT, waveform selection, and target-sound result views.
- Restyle to dark glass panels.
- Do not remove point-click graph values.
- Do not remove ability to slide through audio and update selected frame.

Acceptance:

- User can keep recording while answering.
- UI does not lag worse than current implementation.
- Recording stop/save still works.
- Saved event contains same or richer data than before.
- Back/discard alert still works.

## Phase 5: Tone Match Lab Redesign

### File

- `Tennitus/Views/LabView.swift`

### Target From Prototype

Use `tennitus-design/routes/lab.tsx`.

### Required Layout

Header:

- Status left: `LAB · TONE MATCH`
- Status right: current frequency in Hz.
- Eyebrow: `REFERENCE VS GENERATED`
- Title: `Match the tone you hear.`

Main tone card:

- Large `RotaryDialControl` for frequency:
  - min: current app minimum, or 250 Hz if no constraint exists.
  - max: current app maximum, up to 20 kHz if supported.
  - step: existing app step, or 10 Hz.
  - display formatted with thousands separators.
- Waveform selector:
  - SINE
  - SAW
  - SQUARE or existing supported wave
  - TRI
- Buttons:
  - `Play Reference`
  - `Play Match`
  - Preserve existing tone player and saved profile behavior.

Save:

- There must still be an obvious Save/Lock Match action.
- Saved tone match must update Settings/Profile and event analysis references.

Band filter:

- Preserve existing band filter controls.
- Restyle as dark glass controls or mono pill selectors.

Spectrum review:

- Keep STFT/spectrogram functionality and point value selection.
- Restyle axes, labels, and tooltip for dark theme.

Acceptance:

- Tone match remains clickable.
- Frequency changes audibly.
- Saved profile frequency persists after app restart.
- Waveform selection changes generated sound.
- No crash when zooming/scrolling waveform.

## Phase 6: Settings/Profile Redesign

### File

- `Tennitus/Views/SettingsView.swift`

### Target From Prototype

Use `tennitus-design/routes/settings.tsx`.

### Required Layout

Header:

- Eyebrow: `ACCOUNT · LOCAL-ONLY` or `PROFILE · LOCAL-ONLY`
- Title: user/profile display name if available, otherwise `Profile`.
- Subtitle: streak/event count if available.

Rows card:

Use a single glass grouped list with row labels and right-side values:

- Tinnitus Profile: subtype + saved tone frequency.
- Audiogram: latest HealthKit source/date or `Not connected`.
- Apple Health Sleep: connected/not connected + latest sleep hours.
- Daily Reminder: current setting or `Off`.
- Export Data: `JSON`.
- About Tennitus: app version/build.

Keep existing detailed profile controls, safety screening, reference sounds, baseline sliders, export/import, and AI proxy status lower on the screen or behind rows/navigation links.

Reference sound requirement:

- Keep the current reference sound picker beside/near tinnitus profile.
- User should be able to compare Buzzing/Ringing/Hissing/etc. by listening.
- This must be visible enough to satisfy the design request, not hidden too deep.

Acceptance:

- Settings no longer looks like the old light card style.
- User can still set tinnitus side/sound type/baseline values.
- User can still access Apple Health sync and export.
- No API key entry fields are reintroduced.

## Phase 7: Visual Details To Match Exactly

Apply these across all redesigned screens:

- Background: deep near-black, not pure black.
- Subtle cyan radial glow at top right.
- Subtle amber radial glow at lower left.
- Cards: glass, 24 px-ish rounded corners, 1 px low-opacity border.
- Eyebrows: mono uppercase, 10-11 pt, wide tracking.
- Measurements: mono digits.
- Active cyan glow on primary live/active controls.
- Warnings: amber, not red unless destructive/urgent.
- Buttons: rounded 16-20 px, pressed scale around 0.98-0.99.
- Avoid bright white backgrounds except small primary action contrast where prototype uses foreground fill.
- Avoid huge decorative cards inside cards.
- Keep spacing dense but readable.

## Phase 8: Implementation Order

Do the work in this order to reduce breakage:

1. Update `DesignSystem.swift` tokens and card/screen primitives.
2. Add `AnimatedSpectrumBars`.
3. Add `RotaryDialControl`.
4. Replace/default `TabView` styling with custom `ClinicalBottomNav`.
5. Redesign `TodayView`.
6. Redesign `EventLoggerView` step visuals without changing save/recording logic.
7. Redesign `LabView` tone match surface.
8. Redesign `SettingsView`.
9. Sweep remaining views for unreadable light-theme assumptions.
10. Build and test.

Do not attempt all behavior changes at once. First make the visual shell compile, then migrate each screen.

## Verification Checklist

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Tennitus.xcodeproj \
  -scheme Tennitus \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/TennitusDesignRefreshBuild \
  build
```

Then manually verify in simulator/TestFlight:

- Today loads in dark theme.
- Bottom navigation is dark glass, not iOS default white.
- Log Event opens the redesigned logger.
- Recording continues while answering event questions.
- Event save creates a new log with audio analysis fields.
- STFT/spectrum screen is still available and readable.
- User can tap graph points and see values.
- Tone Match dial is interactive.
- Play Match works.
- Save tone match persists.
- Settings/Profile shows tinnitus profile and reference sound comparison.
- HealthKit sync entries are still accessible.
- No screen has white text on white or black text on black.
- No crash on waveform zoom.

## Known Risks

- A full custom bottom nav can interfere with `NavigationStack` if implemented by replacing `TabView` incorrectly. Keep routing simple and test every tab.
- `RotaryDialControl` can become inaccessible if it only supports drag. Add `accessibilityAdjustableAction`.
- Dark theme can expose hidden `.foregroundStyle(.secondary)` assumptions. Sweep visible screens after the palette change.
- Event logger performance can degrade if spectrum bars recompute from real FFT every frame. The prototype bars should be decorative unless tied to already-throttled analysis values.
- Do not use fake hardcoded dashboard data where real store data exists. Empty states are better than misleading data.

## Definition Of Done

The implementation is complete when:

- The app visually matches the `tennitus-design` prototype language across Today, Logger, Lab, and Settings/Profile.
- Existing app functionality still works.
- Xcode build succeeds.
- No secrets or generated local files are staged.
- Screenshots from simulator show the dark clinical design, not the previous white card interface.
