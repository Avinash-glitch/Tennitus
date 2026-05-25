# Lovable Design Brief: Tennitus iOS App

Create a polished, native-feeling iOS app design for **Tennitus**, a tinnitus and sound-sensitivity companion.

The app should feel like a serious health-adjacent utility: calm, precise, premium, and practical. Do not make a marketing landing page. The first screen should be the usable app experience.

## Product Summary

Tennitus helps users:

- Match their perceived tinnitus tone using a safe signal generator.
- Record real-world sounds that bother them.
- Analyse recorded audio using spectrum and frequency-band features.
- Describe why a sound feels uncomfortable.
- Use AI to interpret compact frequency/loudness summaries and suggest a comfort session.
- Track tinnitus spikes, triggers, sleep, stress, headphones, and noise exposure.
- Export audiologist-ready PDF reports.
- Optionally save indicative audiogram-style results to Apple Health.

Important: the app must not claim to diagnose, cure, treat, or prevent tinnitus or hearing loss. Use language like **comfort session**, **screening**, **indicative**, **pattern**, and **association**.

## Target User

Adults with tinnitus, sound sensitivity, listening fatigue, hyperacusis-like symptoms, or discomfort from specific environmental sounds. They want to understand what frequencies or sound patterns bother them and prepare useful information for an audiologist.

## Design Principles

- Native iOS feel: use SwiftUI-style navigation, cards only where useful, clear tab structure, iOS controls, and restrained typography.
- Calm but not bland: use a clinical/wellness palette with soft teal, graphite, warm amber accents, and high-contrast text.
- Avoid medical overclaiming: every AI or analysis result should be framed as supportive and indicative.
- Make audio data understandable: spectrum views should look professional but readable to non-engineers.
- Keep flows short: logging an event should take under 30 seconds after recording.
- Prioritise accessibility: large tap targets, dynamic type, readable contrast, and no tiny controls for key actions.

## App Structure

Use a bottom tab bar with five tabs:

1. **Today**
2. **Lab**
3. **Trends**
4. **Reports**
5. **Settings**

## Tab 1: Today

Purpose: daily tinnitus check-in and quick spike logging.

Core components:

- Header with today’s date and short insight.
- Daily check-in card:
  - Loudness `0-10`
  - Distress `0-10`
  - Sleep quality `0-10`
  - Stress `0-10`
  - Mood `0-10`
  - Headphone use
  - Noise exposure
  - Optional note
- Primary button: **Save Check-in**
- Secondary action: **Log Spike**
- Small safety note: “For sudden hearing changes, pulsatile tinnitus, vertigo, or severe distress, seek professional support.”

Spike log modal:

- Current loudness `0-10`
- Current distress `0-10`
- Context: home, work, commute, event, outdoors, other
- Recent triggers:
  - noise
  - headphones
  - stress
  - poor sleep
  - caffeine
  - alcohol
  - jaw/neck tension
  - illness
  - medication change
  - unknown
- Optional note
- Buttons:
  - **Save Spike**
  - **Start Comfort Sound**

## Tab 2: Lab

Purpose: the main differentiator. This is where users match tinnitus frequency, record bothering sounds, view spectrum analysis, and receive AI-supported comfort suggestions.

### Lab Home

Show three primary tools:

1. **Tinnitus Tone Match**
2. **Log Sound Event**
3. **Spectrum Review**

Use compact tool rows with icons:

- waveform icon for tone match
- microphone icon for event recording
- chart/spectrum icon for analysis

### Tool 1: Tinnitus Tone Match

Purpose: user adjusts a generated tone to approximate their perceived tinnitus frequency.

UI:

- Large frequency readout: e.g. `4,200 Hz`
- Frequency slider:
  - range: `125 Hz - 12,000 Hz`
  - logarithmic-feeling scale
- Fine adjustment stepper:
  - `-50 Hz`
  - `+50 Hz`
- Volume slider with warning:
  - default very low
  - label: “Keep this barely audible and comfortable.”
- Play/pause button
- Save button: **Save Match**

Show:

- “Current match: 4.2 kHz”
- “Last saved: 3.9 kHz, 2 days ago”

Safety copy:

“This is a personal matching tool, not a hearing test. Stop if the tone feels uncomfortable.”

### Tool 2: Log Sound Event

Purpose: user taps log event, recording starts, then user describes what made the sound bothersome.

Flow:

1. User taps **Log Event**
2. Recording screen opens
3. User records `5-30 seconds`
4. User stops recording
5. App shows waveform and spectrum preview
6. User marks the bothersome segment
7. User describes the sound/background
8. App analyses frequency-band energy and loudness
9. AI suggests a comfort session

Recording screen:

- Large timer
- Live input level meter
- Record/stop button
- Short privacy note:
  “Avoid recording private conversations without consent. Audio stays local unless you choose AI analysis.”

Post-recording screen:

- Waveform timeline
- Draggable selection handles for bothersome segment
- Replay selected segment button
- Text field:
  “What made this sound bothersome?”
- Prompt chips:
  - sharp
  - piercing
  - hissy
  - buzzing
  - metallic
  - boomy
  - clicking
  - sudden
  - repetitive
  - voice/sibilance
  - pressure
  - tinnitus spike
  - anxiety
  - headache
- Reaction intensity slider `0-10`
- Button: **Analyse Event**

### Tool 3: Spectrum Review

Purpose: show the acoustic analysis in a readable way.

Visuals:

- Spectrogram panel
- Frequency spectrum curve
- Broad-band energy bars:
  - `20-250 Hz`
  - `250-500 Hz`
  - `500 Hz-1 kHz`
  - `1-2 kHz`
  - `2-4 kHz`
  - `4-8 kHz`
  - `8-16 kHz`
- Key metrics:
  - dominant band
  - spectral centroid
  - peak level, uncalibrated
  - RMS level, uncalibrated
  - high-frequency energy ratio
  - transient count

Use clear caveat:

“Phone microphone levels are uncalibrated. Frequency patterns are useful for reflection, not diagnosis.”

### AI Comfort Suggestion Screen

Purpose: the AI proxy analyses the user description plus numeric frequency/loudness summary and suggests a comfort session.

Input shown to user:

- User description
- Tinnitus match frequency
- Dominant band
- Band energy summary
- Loudness summary
- Transient count

Output card:

- Title: **Suggested Comfort Session**
- Target range: e.g. `2-4 kHz sensitivity pattern`
- Suggested sound:
  - pink noise
  - brown noise
  - soft rain
  - matched low-level tone
  - high-frequency softened noise
- Duration:
  - default `5 minutes`
- Volume guidance:
  “Start barely audible. Stop if discomfort increases.”
- Rationale bullets:
  - “Your marked segment had strongest energy around 2-4 kHz.”
  - “Your description mentioned sharpness and sibilance.”
  - “The session avoids emphasising the strongest uncomfortable band.”
- Buttons:
  - **Start Session**
  - **Save to Report**
  - **Not Helpful**

Use disclaimer:

“This is a comfort suggestion, not medical treatment.”

## Tab 3: Trends

Purpose: show patterns over time.

Sections:

- Weekly summary
- Loudness and distress trend
- Spike count
- Sleep/stress associations
- Most common triggers
- Sound sensitivity profile

Sound sensitivity profile should show:

- Most common bothersome labels
- Repeated frequency bands
- Tinnitus tone match history
- Example:
  “Marked uncomfortable samples often showed stronger energy in 4-8 kHz. Confidence: low/medium/high.”

Always use association wording:

- “Often appeared with”
- “May be associated with”
- “Not enough data yet”

Avoid:

- “Caused by”
- “Diagnosed”
- “Confirmed sensitivity”

## Tab 4: Reports

Purpose: generate audiologist-ready outputs.

Report options:

1. **Tinnitus Pattern Report**
2. **Sound Sensitivity Report**
3. **Audiogram PDF**

### Tinnitus Pattern Report

Include:

- profile summary
- daily check-ins
- spikes
- sleep/stress/noise/headphone patterns
- AI comfort sessions tried
- user notes

### Sound Sensitivity Report

Include:

- recorded sound events
- user descriptions
- marked bothersome frequency bands
- band energy summaries
- reaction intensity
- comfort suggestions tried

### Audiogram PDF

Design a clean audiogram export screen:

- Audiogram chart:
  - frequency on x-axis
  - dB HL on inverted y-axis
  - right ear red `O`
  - left ear blue `X`
- Indicative ASHA-style tier:
  - normal
  - slight
  - mild
  - moderate
  - moderately severe
  - severe
  - profound
- PTA3 / PTA4 summary
- Calibration status
- Clear label:
  “Indicative screening result, not a clinical diagnosis.”

Buttons:

- **Generate PDF**
- **Share PDF**
- **Save to Apple Health**

Apple Health save note:

“Apple Health can store audiogram threshold points with your permission. Spectrum recordings are not saved to Apple Health.”

## Tab 5: Settings

Sections:

- Tinnitus profile
- Saved tinnitus tone match
- Privacy and data
- Apple Health permissions
- AI analysis settings
- Export/delete data
- Safety information

AI settings:

- backend proxy status for prototype builds
- Toggle:
  “Send only numeric summaries and my description”
- Note:
  “Raw recordings stay on device unless you explicitly export them.”

Apple Health settings:

- Connect Apple Health
- Save audiogram results
- Import headphone audio exposure
- Import sleep summaries

Privacy controls:

- Delete recordings
- Delete analysis
- Delete all local data
- Export JSON/CSV

## Visual Style

Use a restrained palette:

- Background: near-white `#F7FAF9`
- Primary: deep teal `#0F766E`
- Secondary: graphite `#1F2937`
- Accent: warm amber `#D97706`
- Warning: soft red `#DC2626`
- Card background: white
- Borders: cool grey `#D6DEE3`

Avoid:

- purple gradients
- loud neon colours
- decorative blobs/orbs
- marketing hero sections
- cartoon medical imagery

Typography:

- Use iOS-style system font.
- Large numbers for frequency and dB readouts.
- Compact labels for forms.
- Use monospaced digits for frequency, dB, and timer values.

## Key Screens To Generate

Create high-fidelity mobile screens for:

1. Today dashboard
2. Daily check-in form
3. Spike log modal
4. Lab home
5. Tinnitus tone match
6. Recording event screen
7. Mark bothersome segment screen
8. Spectrum analysis screen
9. AI comfort suggestion screen
10. Trends dashboard
11. Sound sensitivity profile
12. Reports dashboard
13. Audiogram PDF preview
14. Apple Health save confirmation
15. Settings/privacy screen

## UX Copy Rules

Use:

- “comfort session”
- “indicative”
- “screening”
- “pattern”
- “association”
- “user-reported”
- “uncalibrated phone microphone”

Avoid:

- “therapy cures tinnitus”
- “diagnosis”
- “treatment plan”
- “confirmed hearing loss”
- “medical-grade”
- “clinically proven”

## Example AI Suggestion Copy

Title:

“Suggested Comfort Session”

Body:

“Your marked segment showed strongest relative energy in the 4-8 kHz band, and your note described the sound as sharp and piercing. Try a 5-minute pink-noise session with gentle high-frequency reduction. Keep the volume barely audible and stop if discomfort increases.”

Footer:

“This is a comfort suggestion based on your recording and description. It is not medical advice.”

## Final Output Expected

Produce a clickable, polished iOS app prototype design that feels ready to hand to a native SwiftUI developer. Prioritise the Lab workflow and Reports workflow, because those are the most differentiated parts of Tennitus.
