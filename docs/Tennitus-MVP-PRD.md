# Tennitus MVP PRD

Version: 0.1  
Date: 2026-05-21  
Owner: Avinash Kannan  
Product stage: MVP discovery and build specification

## 1. Summary

Tennitus is a software-first tinnitus companion for people who want to understand their tinnitus patterns, manage spike episodes, and prepare clearer information for an audiologist or GP.

The first native MVP should focus on seven features:

1. Tinnitus profile onboarding
2. Daily check-in
3. Trigger tracker
4. Spike log
5. Weekly deterministic insight summary
6. Audiologist PDF report
7. Basic masking sounds

The product should not claim to cure, diagnose, treat, or prevent tinnitus. The credible wedge is: "Track tinnitus spikes, understand likely associations, and create appointment-ready reports."

AI is not required for the first native MVP. The core value can be delivered with structured logging, deterministic analytics, native charts, and native PDF generation. AI should be treated as an optional enhancement after the non-AI workflow proves useful.

## 1.1 Native MVP Build Decision

The MVP should be a pure native iOS app written in Swift and SwiftUI.

P0 should not use React Native, Expo, a web wrapper, or a cross-platform abstraction. This keeps the first build simpler, gives better access to iOS audio, local storage, PDF export, HealthKit, widgets, notifications, and future Apple Watch support, and avoids spending early product time maintaining platform glue.

Recommended P0 approach:

- SwiftUI app with native navigation and forms.
- Local-first storage using SwiftData if targeting iOS 17+, or Core Data if targeting iOS 16+.
- Deterministic analytics in pure Swift.
- Native Charts for trends.
- AVFoundation for masking sounds.
- Native PDF generation and iOS share sheet for audiologist reports.
- No required backend, account, cloud sync, or AI dependency.

AI answer: no, AI is not required anywhere in P0. The first sellable version should prove whether users value logging, insights, and reports before adding model cost, privacy friction, safety review, or cloud infrastructure.

## 2. Evidence Summary

Tinnitus is common and clinically heterogeneous. A 2022 JAMA Neurology systematic review estimated adult pooled prevalence of any tinnitus at 14.4%, severe tinnitus at 2.3%, and concluded that tinnitus affects more than 740 million adults globally and is a major problem for more than 120 million people. RNID summarises UK prevalence as over 7 million adults, around 1 in 7.

NICE tinnitus guidance supports the product direction, but also sets important boundaries:

- Clinicians should discuss the person's tinnitus experience, impact, and concerns.
- People should receive tailored information about tinnitus, including what may make it worse, such as stress or loud noise.
- Adults can be assessed with the Tinnitus Functional Index, but licensing must be checked before embedding it in a commercial app.
- Sleep and psychological impact should be considered.
- Audiological assessment should be offered to people with tinnitus.
- NICE was unable to make a routine practice recommendation for sound therapy, so masking sounds should be positioned as optional comfort/support, not treatment.
- Digital CBT is recommended only as tinnitus-related CBT delivered by appropriately qualified psychologists, so Tennitus should not position its AI as CBT.

Mobile ecological momentary assessment (EMA) research supports repeated lightweight tracking. TrackYourTinnitus research shows that repeated mobile questionnaires can capture fluctuating tinnitus experience. A 2025 npj Digital Medicine study found external sounds reduced tinnitus in about 20% of users, worsened it in about 5%, and had no effect in about 75%, which means sound features need personalisation and careful wording. The same study shows adherence is hard: many registered users did not provide enough EMA data for analysis, so the MVP must keep check-ins short.

Privacy and regulation also matter. Tinnitus logs are health data. In the UK, ICO guidance treats data concerning health as special category data, requiring extra care. MHRA guidance says software and AI products that meet a medical purpose may be regulated as software as a medical device. For v1, Tennitus should be scoped as a tracking, self-management, and report-generation tool unless you deliberately choose a regulated medical route.

## 3. Product Positioning

### Recommended positioning

"A tinnitus tracker that helps you understand your patterns, manage spikes, and prepare clear reports for your audiologist."

### Avoided positioning

- "Cures tinnitus"
- "Treats tinnitus"
- "Prevents hearing damage"
- "Diagnoses tinnitus causes"
- "AI audiologist"
- "Medical-grade sound therapy"
- "Clinically proven relief" unless backed by product-specific clinical evidence

## 3.1 Competitive Reality and Differentiation

Manual tracking, trigger logging, sounds, and even exportable reports are not unique features by themselves. Existing products already cover parts of this space:

- TrackYourTinnitus supports ecological momentary assessment and charts for tinnitus variability.
- Tinnilog offers fast entries, Apple Watch/widgets, trigger detection, and CSV export.
- Tinnitus Journey publicly lists daily tracking across many auditory/lifestyle biomarkers, spike logging, AI-powered goals, and exportable PDF reports.
- Lushh publicly positions itself around sound therapy, CBT-style tools, notch therapy, daily tinnitus tracking, and exportable PDF reports.
- MindEar and Oto-style products focus more heavily on sound therapy, CBT, education, guided support, and AI/chatbot coaching.
- ReSound Relief focuses on sound therapy, relaxation, and distraction support.

This means Tennitus should not be built as "another tinnitus diary." The defensible wedge should be one of the following:

1. Clinician-first reporting
   - Build the best pre-appointment report for audiologists, ENTs, and GPs.
   - Validate the report with 5-10 clinicians before polishing consumer features.
   - Optimise around "does this save appointment time and improve patient recall?"

2. Low-burden tracking
   - Use manual check-ins only where subjective input is required.
   - Use Apple HealthKit in P1 to import sleep, activity, and audio exposure context where available.
   - Use reminders and event prompts sparingly to avoid symptom fixation.

3. Data-quality-aware insights
   - Do not generate generic coaching text.
   - Show confidence levels, sample size, missing data, and why an association is or is not shown.
   - Make summaries useful for patient history and appointment preparation, not clinical advice.

4. UK/NICE-aligned appointment preparation
   - Use UK-friendly language, GP/audiology pathways, and NICE-aligned safety boundaries.
   - Avoid unlicensed questionnaire use until permissions are checked.

5. Audio discomfort mapping
   - Let users record short real-world sounds, mark the part that bothers them, and describe the sensation in plain language.
   - Analyse the marked segment locally for acoustic patterns such as dominant bands, harshness, transient peaks, repetition, and high-frequency energy.
   - Build a "sounds that bother me" profile for reflection and audiologist discussion.

6. Screening audiogram workflow
   - Offer an indicative hearing-threshold screen with clear calibration and environment caveats.
   - Show ASHA-style degree bands only as an indicative screening tier, not a diagnosis.
   - Export a native audiogram PDF and, with explicit permission, save structured audiogram points to Apple Health.

7. A focused paid report product
   - Instead of trying to win as a broad tinnitus relief app, test a narrower offer:
     "Track for 14 days and generate an appointment-ready tinnitus report."

### Differentiation test

Before building beyond prototype, Tennitus must pass this test:

"Would a user or clinician choose this report/workflow over a generic tracker, spreadsheet, or existing tinnitus app?"

If the answer is no, the product should pivot toward a narrower workflow, likely audiologist intake/reporting rather than broad B2C tinnitus management.

## 4. Target Users

### Primary user

Adults with subjective tinnitus who experience fluctuating symptoms and want to understand what affects their tinnitus.

### Secondary user

Adults preparing for a GP, ENT, audiology, or private tinnitus clinic appointment.

### Future buyer/user

Audiologists or tinnitus clinics who want structured patient pre-appointment data.

## 5. Core User Jobs

1. "I want to know what tends to make my tinnitus worse."
2. "I want to capture spikes when they happen, not rely on memory."
3. "I want something calming and simple when I am having a bad spike."
4. "I want to show my audiologist useful information instead of vague descriptions."
5. "I want weekly insight without obsessively checking my tinnitus all day."

## 6. Goals and Non-Goals

### MVP goals

- Make tinnitus tracking fast enough to become habitual.
- Capture meaningful context around spikes and daily variation.
- Generate cautious, useful deterministic insights based on associations, not causation.
- Produce a clean native PDF report suitable for an audiologist or GP appointment.
- Provide basic user-controlled masking sounds for comfort.
- Prove the app's value without requiring AI, cloud sync, or a backend.

### MVP non-goals

- Real-time filtering of Spotify, Apple Music, YouTube, or system audio.
- Diagnosis of tinnitus cause.
- Hearing test, audiogram, or medical assessment.
- Psychoacoustic pitch/loudness matching.
- Treatment recommendations.
- CBT or mental health therapy delivered by AI.
- Emergency triage beyond clear signposting.
- Clinician dashboard in v1.
- Claims of clinical efficacy.
- Android app or cross-platform codebase in the first MVP.
- Server-dependent weekly insights or report generation.
- AI-generated summaries in P0.

## 7. MVP Scope

### P0 features

- Onboarding tinnitus profile
- Daily check-in
- Trigger tracker
- Spike log
- Weekly deterministic insight summary
- Native audiologist PDF report
- Basic masking sounds
- Audio discomfort sample recorder
- Real-time spectrum analyser for recorded and live microphone audio
- Consent, privacy controls, local export, delete local data

### P1 features

- Custom trigger tags
- Calendar and trend views
- Optional AI summary drafting from structured metrics
- Optional health-data import via Apple HealthKit
- Indicative hearing screen with ASHA-style severity tier
- Audiogram PDF export
- Apple Health audiogram save via HealthKit
- Optional iCloud sync or account-backed cloud sync
- More sound types and favourites
- Clinician-facing report notes
- Filtered playback previews for user-recorded discomfort samples

### P2 features

- Wearable/headphone integration
- Android app after iOS demand is validated
- Ambient sound sensing
- Clinic portal
- Validated questionnaire integration after licensing review
- Paid clinic accounts
- Real-time environmental trigger detection after explicit user opt-in and clinical/privacy review

## 8. Feature Requirements

## 8.1 Tinnitus Profile Onboarding

### Purpose

Capture a baseline profile so the app can personalise check-ins, reports, and insights without asking too much daily.

### User story

As a user with tinnitus, I want to describe my tinnitus once so the app can understand my baseline and produce a useful report later.

### P0 requirements

The onboarding flow must collect:

- Age range, country, and timezone
- Tinnitus duration: new, weeks, months, years
- Onset pattern: sudden, gradual, unsure
- Laterality: left, right, both, inside head, unsure
- Pattern: constant, intermittent, fluctuating
- Perceived sound type: ringing, buzzing, hissing, whooshing, pulsing, clicking, multiple, other
- Baseline loudness: 0-10 visual analogue scale
- Baseline distress/bother: 0-10 visual analogue scale
- Sleep impact: 0-10
- Concentration impact: 0-10
- Hearing difficulty: none, mild, moderate, severe, unsure
- Current support: none, GP, audiologist, ENT, hearing aids, therapy, other
- Main goal: understand triggers, manage spikes, prepare appointment, sleep better, reduce anxiety, other

### Red-flag signposting

The app must include a non-alarming safety screen. If users report certain features, the app should advise seeking appropriate clinical advice and link to NHS/NICE-style guidance.

Examples:

- Sudden hearing loss
- Pulsatile tinnitus
- Persistent one-sided tinnitus
- Tinnitus with neurological symptoms
- Acute severe vertigo
- Severe distress or thoughts of self-harm

The app must not attempt to diagnose or triage urgency beyond clear wording and links.

### Acceptance criteria

- User can complete onboarding in under 3 minutes.
- All fields except safety-relevant fields are skippable.
- User can edit the profile later.
- Onboarding stores a timestamped baseline snapshot.
- The report can include both current profile and baseline profile.

## 8.2 Daily Check-In

### Purpose

Create a low-friction daily habit and generate enough structured data to detect patterns.

### User story

As a user, I want to log my tinnitus in under 30 seconds so I can build useful history without feeling burdened.

### P0 requirements

Daily check-in must include:

- Tinnitus loudness today: 0-10
- Tinnitus distress/bother today: 0-10
- Sleep quality last night: 0-10
- Stress today: 0-10
- Mood today: 0-10
- Headphone use: none, under 1 hour, 1-3 hours, 3+ hours
- Noise exposure: quiet, moderate, loud, very loud
- Free-text note, optional

### P1 requirements

- Reminder time chosen by user
- Skip reason: forgot, no time, did not want to focus on tinnitus, other
- Quick check-in widget
- Streaks should be gentle and optional, not guilt-driven

### Acceptance criteria

- Returning users can submit a check-in in under 30 seconds.
- Check-in uses 0-10 scales consistently.
- The app handles missed days without punishing the user.
- Weekly insights only run when there are enough entries to avoid weak conclusions.

## 8.3 Trigger Tracker

### Purpose

Capture likely contextual factors that may be associated with tinnitus changes.

### User story

As a user, I want to log likely triggers quickly so I can see what is associated with better or worse days.

### P0 trigger categories

- Sleep: hours, perceived quality
- Stress: 0-10
- Noise exposure: quiet, moderate, loud, very loud
- Headphones: duration bucket, perceived volume bucket
- Caffeine: none, low, medium, high
- Alcohol: none, low, medium, high
- Exercise: none, light, moderate, intense
- Jaw/neck tension: 0-10
- Illness/congestion: yes/no
- Medication change: yes/no plus note
- Workload/screen time: low, medium, high
- Menstrual cycle/hormonal note: optional and only if user enables it
- Custom trigger tags

### Technical note

The app should initially rely on user-reported noise exposure rather than claiming calibrated decibel measurements. Smartphone microphones vary by device, OS, permissions, calibration, case, placement, and whether the mic is covered. Ambient sensing can be a future feature, but v1 should not present it as accurate SPL measurement.

### Insight language

Use:

- "associated with"
- "often happened on days when"
- "may be linked"
- "not enough data yet"

Do not use:

- "caused by"
- "diagnosed"
- "proven trigger"
- "avoid permanently"

### Acceptance criteria

- Users can log triggers from daily check-in and spike log.
- Users can add custom tags.
- Trigger insights require minimum data thresholds.
- The same trigger taxonomy appears in charts, weekly summaries, and PDF reports.

## 8.4 Spike Log

### Purpose

Capture high-distress events in context and give users a structured way to respond.

### User story

As a user having a tinnitus spike, I want a one-tap way to log it and access a short calming routine or sound option.

### P0 requirements

Spike log must include:

- One-tap "Log spike" button
- Current loudness: 0-10
- Current distress: 0-10
- Start time auto-filled
- End time optional
- Location context: home, work, commute, event, outdoors, other
- Recent triggers: noise, headphones, stress, sleep, caffeine, alcohol, jaw/neck tension, illness, medication, unknown
- Notes
- Optional masking sound launch
- Optional 2-5 minute calming routine

### Safety guardrails

If distress is very high, the app can ask: "Are you feeling unsafe or at risk of harming yourself?" If yes, show crisis support resources and emergency guidance appropriate to the user's country. Do not route this through an AI conversation.

### Acceptance criteria

- Spike logging can start with one tap.
- The user can finish details later.
- Spike events are visible in calendar and report.
- Spike data contributes to weekly insight only after enough samples.

## 8.5 Weekly Deterministic Insight Summary

### Purpose

Turn structured logs into a concise weekly reflection that helps the user understand patterns without overclaiming. P0 should be generated entirely on device from structured data.

### User story

As a user, I want a weekly summary that explains what changed, what might be associated with spikes, and what to bring up with my audiologist.

### P0 requirements

Weekly summary must include:

- Average loudness, distress, sleep, and stress for the week
- Number of check-ins
- Number of spikes
- Biggest changes versus previous week
- Top associated triggers, if data supports it
- Plain-language note about uncertainty
- Suggested questions for clinician, if relevant
- Encouragement to seek professional advice when red-flag symptoms are logged

### Technical approach

Use deterministic analytics only in P0. AI is not required to make the first version useful because the summary can be assembled from metrics, thresholded associations, and predefined clinician-question templates.

Pipeline:

1. Aggregate structured data in code.
2. Compute simple descriptive statistics.
3. Run association checks only when minimum data thresholds are met.
4. Generate a structured `WeeklyInsight` object.
5. Render the summary using fixed native templates and cautious wording.
6. Apply deterministic safety flags before display.

### Minimum thresholds

- Weekly summary: at least 3 check-ins in the week.
- Trigger association: at least 14 total check-ins and at least 3 occurrences of the trigger.
- Spike pattern: at least 3 spike logs.
- Do not compare against a previous week unless previous week has at least 3 check-ins.

### Wording rules

The summary must:

- Refer to "patterns" and "associations", not causes.
- State when data is too limited.
- Avoid medical advice.
- Avoid medication advice.
- Avoid recommending stopping prescribed treatment.
- Suggest discussing significant changes with a clinician.

### AI strategy

Do not use AI in P0.

AI can be considered in P1 only if user testing shows that deterministic summaries feel too mechanical or if free-text notes become important. Even then, AI should only rewrite or compress a structured insight object; it must not invent associations, diagnose, triage, or recommend treatment.

Potential P1 AI uses:

- Rephrasing weekly metrics into friendlier language
- Extracting tags from optional user notes
- Drafting report narrative from already-computed metrics

All AI outputs, if added later, must be regenerate-able from stored structured data and optional user-approved notes.

### Acceptance criteria

- Summary generation works offline.
- The same source data can reproduce the summary.
- The user can see which logged factors contributed to the summary.
- Summary includes a confidence level: low, medium, or high.

## 8.6 Audiologist PDF Report

### Purpose

Convert user logs into a concise, clinician-friendly report for appointment preparation.

### User story

As a patient, I want to export a clear tinnitus summary so my audiologist can quickly understand my symptoms, patterns, and concerns.

### P0 report sections

1. Cover
   - User name or initials, optional
   - Date range
   - Generated date
   - Disclaimer: user-reported tracking data, not a diagnosis

2. Tinnitus profile
   - Duration and onset
   - Laterality
   - Sound type
   - Pattern
   - Baseline and current loudness/distress
   - Hearing difficulty
   - Current care/support

3. Timeline
   - Daily loudness and distress chart
   - Spike markers
   - Sleep and stress overlay or separate chart

4. Trigger summary
   - Most frequently logged triggers
   - Triggers most associated with worse days
   - Clear caveat: correlation only, self-reported data

5. Spike summary
   - Number of spikes
   - Typical time of day
   - Common contexts
   - Average distress during spike
   - Notes from most severe spikes

6. Sleep and wellbeing
   - Sleep impact trend
   - Stress/mood trend
   - Any severe distress flags shown as "patient may wish to discuss"

7. Sound/masking notes
   - Sounds tried
   - Which sounds felt helpful, neutral, or worse
   - Do not label masking as treatment

8. Sound discomfort samples
   - Number of samples recorded
   - User-selected examples, if included
   - User labels and reaction ratings
   - Repeated acoustic patterns, if enough samples exist
   - Caveat: phone recordings are not calibrated clinical measurements

9. Questions for clinician
   - Generated from user profile and logs
   - Example: "Should I have an audiological assessment?"
   - Example: "Are my one-sided/pulsatile symptoms something to assess?"
   - Example: "Could jaw/neck tension or hearing loss be relevant?"

### Validated questionnaires

NICE suggests considering TFI for adults. However, TFI is copyrighted by Oregon Health and Science University, and commercial use may require permission. MVP should use simple 0-10 visual analogue scales first, then review licensing before embedding TFI, THI, TQ, or mini-TQ.

### Acceptance criteria

- User can generate a PDF for 7, 14, 30, or 90 days.
- Report is readable by a clinician in under 3 minutes.
- Report includes only user-approved personal identifiers.
- Report can be deleted.
- Report includes source data date range and caveats.

## 8.7 Basic Masking Sounds

### Purpose

Provide simple, controllable background sounds that some users may find helpful for comfort, focus, or sleep.

### User story

As a user, I want to play simple sounds that may help me feel less aware of tinnitus during a spike or at bedtime.

### P0 sound library

- White noise
- Pink noise
- Brown noise
- Rain
- Ocean/waves
- Fan
- Soft stream
- Low-pass noise
- Narrowband-style noise presets without claiming custom therapy

### P0 controls

- Play/pause
- Timer: 5, 10, 20, 30, 60 minutes
- Volume slider
- Fade out
- Favourite sound
- "This helped / neutral / made worse" feedback

### Technical note

Keep sounds local where possible to reduce latency, data use, and privacy concerns. The app should remind users to keep playback at a comfortable volume. Avoid loudness matching tests and do not ask users to raise sound to uncomfortable levels.

### Acceptance criteria

- Sounds can play in the background, subject to iOS audio session and background audio rules.
- Timer and fade-out work reliably.
- User feedback on each sound feeds into report and future personalisation.
- The UI states that sounds are for comfort/support, not a guaranteed treatment.

## 8.8 Health Data Import

### Purpose

Reduce manual logging burden and improve trigger analysis by importing relevant sleep, activity, and audio exposure context from user-approved health data sources.

### Recommendation

Health data import should be P1, not required for the first prototype. Manual daily check-ins should remain the P0 source of truth because they are simpler to build, easier to validate, and work for users without wearables.

### Supported platforms

iOS:

- Use Apple HealthKit.
- HealthKit can provide a central store for health and fitness data on iPhone and Apple Watch with explicit user permission.
- Relevant categories include sleep analysis, steps, workouts/activity, heart rate, mindfulness where available, headphone audio exposure, and environmental audio exposure where device support exists.

### P1 import fields

The app may import daily summaries for:

- Sleep duration
- Sleep start and end time
- Sleep stage summary, if available
- Resting heart rate, if available
- Heart rate during sleep, if available
- Steps
- Exercise sessions
- Active minutes or workout duration
- Mindfulness/breathing minutes, if available
- Headphone audio exposure, where available
- Environmental audio exposure, where available

### Important constraints

- Imported data depends on the user's device, wearable, OS, app permissions, and whether another app writes the data.
- Sleep data is generally useful after the sleep session has completed, not as a real-time spike detector.
- HealthKit audio exposure is strongest for Apple ecosystem data; do not assume non-Apple headphones or all devices provide reliable exposure data.
- Imported data should be labelled by source and timestamp.
- Users must be able to disconnect integrations and delete imported data.

### Product logic

Imported health data should pre-fill or supplement manual trigger fields. For example:

- If sleep duration is available, pre-fill "hours slept".
- If sleep quality is not available, still ask the user for perceived sleep quality.
- If headphone audio exposure is available, use it as context for reports and patterns.
- If imported data conflicts with user input, preserve both and show user-reported values as primary for subjective experience.

### Privacy requirements

- Ask only for the minimum permissions needed.
- Explain why each data type is requested.
- Allow users to enable sleep without enabling heart rate or audio exposure.
- Do not send raw health time series to any external service unless the user explicitly opts into a later cloud/AI feature.
- Prefer daily aggregates for summaries and reports.
- Treat imported data as health data under the same privacy rules as tinnitus logs.

### Acceptance criteria

- User can connect and disconnect Apple Health.
- User can choose specific data categories to share.
- Imported fields clearly show their source.
- Manual logging remains usable without any health integration.
- Weekly insights explain when imported data was used.
- Audiologist reports identify imported health-data sections as device/app-derived, not clinician-measured.

## 8.9 Audio Discomfort Sample Recorder

### Purpose

Capture real-world sounds that bother the user, let the user mark the uncomfortable part, and translate subjective discomfort into a structured acoustic profile.

This is a stronger differentiator than a standard tinnitus diary because it focuses on the user's sound tolerance profile: "which real sounds bother me, what do they have in common, and how can I explain that clearly to a clinician?"

### User story

As a user, I want to record a short sound, highlight the part that bothered me, and describe what I felt so the app can build a clearer picture of my sound sensitivity.

### P0 workflow

1. User taps "Record sound sample".
2. App shows a privacy reminder before recording.
3. User records a short clip, recommended 5-30 seconds.
4. User replays the clip at a safe, comfortable volume.
5. User marks one or more uncomfortable time ranges on the waveform.
6. User describes the discomfort in plain language.
7. User rates reaction intensity from 0-10.
8. App runs local acoustic analysis on the marked segment.
9. App stores the result as a discomfort sample.
10. App includes selected samples in the audiologist report.

### P0 user labels

The user can describe the uncomfortable part using:

- Sharp
- Piercing
- Hissing
- Buzzing
- Ringing
- Metallic
- Boomy
- Rumbly
- Clicking
- Crackling
- Sudden/loud
- Repetitive
- Voice/sibilance
- Unknown
- Other free text

The user can describe body/mental response using:

- Ear pain
- Pressure/fullness
- Tinnitus spike
- Anxiety/panic
- Irritation/anger
- Nausea/dizziness
- Headache
- Startle response
- Hard to concentrate
- Other free text

### Local acoustic analysis

The app should analyse only the marked segment, not the full recording unless needed for comparison.

P0 features:

- Duration of marked segment
- Peak amplitude, uncalibrated
- RMS level, uncalibrated
- Dynamic range estimate
- Spectral centroid
- Dominant frequency band
- Energy by broad bands: 20-250 Hz, 250-500 Hz, 500 Hz-1 kHz, 1-2 kHz, 2-4 kHz, 4-8 kHz, 8-16 kHz
- High-frequency energy ratio
- Transient/impulse count
- Repetition/modulation estimate
- Optional spectrogram preview

The app must not claim calibrated decibel accuracy from the phone microphone unless a calibrated microphone workflow is introduced later.

### Insight logic

After enough discomfort samples, the app can generate cautious patterns:

- "Your marked uncomfortable segments often had strong energy around 2-4 kHz."
- "Several uncomfortable samples were short, sudden transients rather than sustained sounds."
- "Voice/sibilance labels were often associated with higher 4-8 kHz energy."
- "Not enough samples yet to identify a repeated pattern."

Minimum threshold:

- Show a personal sound pattern only after at least 5 marked samples.
- Show band-level patterns only if at least 3 samples share a similar band pattern.

### Filtered preview, P1

The app may offer a local playback preview that reduces the marked acoustic pattern:

- Gentle high-cut
- Narrow band reduction
- De-essing style high-frequency reduction
- Transient softening
- Low rumble reduction

This must be framed as a preview/experiment, not treatment. It only applies to the recorded clip or in-app masking/audio, not system audio or AirPods globally.

### Privacy and consent

Audio recordings may capture other people, private conversations, locations, or sensitive context.

The app must:

- Ask microphone permission only when needed.
- Warn users not to record private conversations without consent.
- Store recordings locally by default.
- Allow users to delete each sample and its derived analysis.
- Allow users to keep analysis while deleting raw audio.
- Exclude raw audio from any external AI/cloud processing in P0.
- Let users decide whether a sample appears in the audiologist report.

### Acceptance criteria

- User can record, play back, mark a time range, and save a discomfort sample.
- User can label and rate the marked segment.
- App computes local acoustic features for the marked segment.
- App shows plain-language, non-diagnostic analysis.
- User can delete raw audio and derived analysis.
- Audiologist report can include a summary of sound sensitivity samples.

## 8.10 Spectrum Analyser, Indicative Hearing Screen, and Audiogram Export

### Purpose

Combine a Spektral-style analyser for real-world sounds with a separate hearing-threshold workflow that can produce an indicative audiogram, ASHA-style degree tier, PDF export, and Apple Health save.

These are related but technically different:

- Spectrum analysis answers: "What frequencies and acoustic patterns are present in this sound?"
- Audiogram screening answers: "At what level can this user detect tones at standard test frequencies?"

The app must never infer hearing-loss severity from a room recording or spectrogram alone.

### P0 spectrum analyser

The app should provide a live and recorded audio analyser:

- Live microphone spectrum view
- Recording waveform
- Spectrogram view
- Peak frequency markers
- Broad-band energy bars
- User-marked uncomfortable segment
- Segment comparison: uncomfortable part vs surrounding audio
- Labels and notes from the user

Recommended analysis:

- FFT using Accelerate/vDSP
- Windowed spectral analysis with Hann window
- Log-frequency display from roughly 20 Hz to 16 kHz
- Broad bands: 20-250 Hz, 250-500 Hz, 500 Hz-1 kHz, 1-2 kHz, 2-4 kHz, 4-8 kHz, 8-16 kHz
- Spectral centroid, high-frequency ratio, transient count, and dominant band

The spectrum analyser should show relative level unless a calibrated microphone workflow exists. Do not display clinical dB HL from microphone analysis.

### P1 indicative hearing screen

The app may include a pure-tone-style hearing screen, but it must be framed carefully.

Recommended frequencies:

- 250 Hz
- 500 Hz
- 1 kHz
- 2 kHz
- 3 kHz
- 4 kHz
- 6 kHz
- 8 kHz

Recommended per-ear workflow:

1. User chooses headphone model and confirms quiet environment.
2. App performs left-ear and right-ear tone presentation separately.
3. User adjusts/responds to tones to estimate threshold per frequency.
4. App stores threshold points in dB HL only if the output calibration basis is known.
5. If calibration is not known, app stores results as uncalibrated screening levels and does not present them as a clinical audiogram.

### ASHA-style indicative severity tier

ASHA degree bands commonly classify hearing thresholds as:

- Normal: -10 to 15 dB HL
- Slight: 16 to 25 dB HL
- Mild: 26 to 40 dB HL
- Moderate: 41 to 55 dB HL
- Moderately severe: 56 to 70 dB HL
- Severe: 71 to 90 dB HL
- Profound: 91+ dB HL

Tennitus should label this as:

"Indicative ASHA-style screening tier"

Do not label it as:

- diagnosis
- clinical severity
- confirmed hearing loss
- medical audiogram unless clinically validated and calibrated

Suggested calculations:

- PTA3: average of 500 Hz, 1 kHz, and 2 kHz per ear
- PTA4: average of 500 Hz, 1 kHz, 2 kHz, and 4 kHz per ear
- High-frequency average: 3 kHz, 4 kHz, 6 kHz, and 8 kHz per ear
- Worst-frequency tier: most elevated threshold in the tested range

The PDF should show all calculations separately. A single severity label can hide high-frequency notches or asymmetric results.

### Audiogram PDF export

The native PDF should include:

- Audiogram chart with frequency on a log axis
- dB HL on an inverted vertical axis from about -10 to 120 dB HL
- Right ear shown with red O markers
- Left ear shown with blue X markers
- Threshold table by frequency and ear
- PTA3, PTA4, high-frequency average, and worst-frequency summary
- Indicative ASHA-style tier per ear
- Device, headphone model, calibration status, test environment, and date/time
- Clear disclaimer: "Screening result, not a clinical diagnosis"
- Optional appendix with discomfort samples and spectrum-analysis summaries

### Apple Health save

Apple Health supports audiogram samples through HealthKit. Native iOS can request permission to write audiogram samples, create `HKAudiogramSample` values, and save them through `HKHealthStore`.

Constraints:

- The user must explicitly grant HealthKit permission.
- The app cannot silently or automatically write to Apple Health without permission.
- HealthKit can store audiogram threshold points, not arbitrary spectrum analyser data.
- Raw recordings and spectrograms should stay in Tennitus, not Apple Health.
- Saved samples should include metadata identifying Tennitus, calibration status, headphone/device details, and whether the result is a screening estimate.

HealthKit save should be available only when:

- The user completed a threshold screen for at least one ear.
- Frequency, ear side, and threshold values are present.
- The app can represent the points as `HKAudiogramSensitivityPoint`.
- The user confirms they want to save the result to Apple Health.

### Acceptance criteria

- User can view a live spectrum analyser.
- User can record audio, mark a bothersome segment, and inspect the spectrum for that segment.
- User can run a separate hearing-threshold screen per ear.
- App shows ASHA-style tiers only with screening/indicative language.
- User can export an audiogram PDF.
- User can save a completed audiogram-style screen to Apple Health after explicit permission.
- The app keeps spectrum analysis, hearing threshold screening, and tinnitus tracking conceptually separate in the UI.

## 9. Data Model

### Core entities

User

- id
- email or auth provider id
- created_at
- country
- timezone
- consent_version
- privacy_settings

TinnitusProfile

- id
- user_id
- created_at
- updated_at
- onset_date_or_bucket
- onset_pattern
- duration_bucket
- laterality
- sound_types
- pattern
- baseline_loudness
- baseline_distress
- sleep_impact
- concentration_impact
- hearing_difficulty
- current_support
- main_goal
- red_flag_answers

DailyCheckIn

- id
- user_id
- date
- created_at
- loudness_0_10
- distress_0_10
- sleep_quality_0_10
- stress_0_10
- mood_0_10
- headphone_duration_bucket
- headphone_volume_bucket
- noise_exposure_bucket
- caffeine_bucket
- alcohol_bucket
- jaw_neck_tension_0_10
- illness_congestion
- medication_change
- notes

SpikeLog

- id
- user_id
- started_at
- ended_at
- loudness_0_10
- distress_0_10
- context
- trigger_tags
- notes
- sound_used_id
- sound_helpfulness

TriggerTag

- id
- user_id nullable for system tags
- name
- category
- created_at

SoundSession

- id
- user_id
- sound_id
- started_at
- duration_seconds
- timer_seconds
- volume_percent
- feedback

HealthIntegration

- id
- user_id
- platform: apple_healthkit
- enabled_data_types
- connected_at
- last_sync_at
- status

DailyHealthSnapshot

- id
- user_id
- date
- source_platform
- source_app_or_device
- sleep_duration_minutes
- sleep_start_at
- sleep_end_at
- sleep_stage_summary_json
- resting_heart_rate
- sleep_heart_rate_avg
- steps
- exercise_minutes
- mindfulness_minutes
- headphone_audio_exposure_summary_json
- environmental_audio_exposure_summary_json
- imported_at

AudioDiscomfortSample

- id
- user_id
- recorded_at
- title
- audio_file_path nullable if raw audio deleted
- duration_seconds
- marked_start_seconds
- marked_end_seconds
- reaction_intensity_0_10
- sound_labels
- response_labels
- user_description
- include_in_report
- raw_audio_deleted_at
- analysis_json
- created_at
- updated_at

AudioSegmentAnalysis

- id
- sample_id
- analysed_at
- peak_amplitude_uncalibrated
- rms_amplitude_uncalibrated
- dynamic_range_estimate
- spectral_centroid_hz
- dominant_band
- band_energy_json
- high_frequency_energy_ratio
- transient_count
- repetition_estimate
- analysis_version

HearingScreenSession

- id
- user_id
- started_at
- completed_at
- headphone_model
- device_model
- calibration_status
- environment_self_report
- notes
- apple_health_saved_at nullable
- pdf_exported_at nullable

HearingThresholdPoint

- id
- session_id
- ear: left, right
- frequency_hz
- threshold_db_hl nullable
- uncalibrated_level nullable
- response_method
- created_at

AudiogramSummary

- id
- session_id
- right_pta3_db_hl nullable
- left_pta3_db_hl nullable
- right_pta4_db_hl nullable
- left_pta4_db_hl nullable
- right_high_frequency_average_db_hl nullable
- left_high_frequency_average_db_hl nullable
- right_indicative_asha_tier
- left_indicative_asha_tier
- asymmetry_flag
- summary_version

WeeklyInsight

- id
- user_id
- week_start
- week_end
- generated_at
- data_quality
- structured_metrics_json
- rendered_summary
- safety_flags
- ai_summary nullable, P1 only
- ai_model_name nullable, P1 only
- ai_prompt_version nullable, P1 only

AudiologistReport

- id
- user_id
- date_range_start
- date_range_end
- generated_at
- file_path_or_storage_key
- included_sections
- summary_version
- deleted_at

## 10. Analytics Logic

### Descriptive metrics

- Mean loudness and distress
- Median loudness and distress
- Highest loudness and distress
- Number of spikes
- Check-in completion rate
- Average sleep quality
- Average stress
- Most frequent triggers

### Association logic

Start with transparent, simple rules:

- Compare average loudness/distress on days with trigger vs days without trigger.
- Compare spike probability on days with trigger vs days without trigger.
- Use rolling 7-day and 30-day views.
- Show only if minimum sample thresholds are met.

Avoid complex prediction models in v1. They are not needed to validate demand and can create false authority.

### Insight quality levels

Low:

- Fewer than 14 check-ins
- Missing many days
- Few trigger occurrences

Medium:

- 14-29 check-ins
- At least 3 occurrences of relevant trigger

High:

- 30+ check-ins
- Repeated trigger pattern across multiple weeks

## 11. Safety, Privacy, and Compliance

### Safety principles

- Do not diagnose.
- Do not recommend medication changes.
- Do not present AI as a clinician.
- Use crisis resources for self-harm risk.
- Use clinician signposting for red flags.
- Use conservative language for all pattern insights.

### Privacy principles

- Treat all tinnitus and wellbeing data as health data.
- Collect the minimum needed for user value.
- Encrypt data in transit and at rest.
- Allow data export.
- Allow local data deletion.
- Keep P0 fully functional without external AI or backend calls.
- If AI is added later, keep prompts free of unnecessary identifiers and log prompt/output versions.
- Have a clear privacy policy before public launch.

### UK regulatory boundary

The v1 intended use should be:

"Tennitus helps adults record tinnitus-related symptoms, lifestyle context, and self-reported triggers, and generate summaries for personal reflection and healthcare discussions."

Avoid intended use language like:

"Tennitus treats, diagnoses, predicts, prevents, or monitors disease progression."

If the product later provides clinical decision support, automated triage, treatment recommendations, or claims clinical outcomes, review MHRA software as a medical device guidance and obtain regulatory advice.

## 12. Suggested Technical Architecture

### Native iOS app

Recommended stack:

- Swift
- SwiftUI
- SwiftData for local structured storage, or Core Data if broader backwards compatibility is required
- Charts framework for trends and association views
- AVFoundation for local masking sound playback, timers, microphone capture, tone generation, background audio mode, and fade-out
- Accelerate/vDSP for native FFT and spectrum analysis
- HealthKit for reading audio/sleep context and writing user-approved audiogram samples
- PDFKit or UIKit PDF rendering for native report export
- AppStorage/Keychain for preferences, consent version, and lightweight secure settings
- StoreKit for paid report or premium testing when monetisation is added

Minimum target recommendation:

- iOS 17+ if using SwiftData and modern Observation.
- iOS 16+ only if there is a strong market reason, in which case use Core Data and `ObservableObject` patterns.

### App structure

Use a simple native app shell:

- `TabView` with Today, Trends, Sounds, Reports, and Settings.
- `NavigationStack` per tab for detail flows.
- Small SwiftUI views with local `@State` for form state.
- App-level services injected through SwiftUI environment where useful.
- Deterministic analytics implemented as pure Swift services that can be unit tested without UI.

### Local-first data

P0 should work without account creation:

- Store all tinnitus logs locally on device.
- Export user data as CSV or JSON.
- Delete all local data from Settings.
- Keep generated PDFs local unless the user shares them using the native iOS share sheet.
- Do not require Supabase, Firebase, a custom backend, or cloud sync for P0.

Cloud sync can be added later if retention or paid-user feedback justifies it. If added, iCloud private database should be considered before a custom backend because this is a personal health-adjacent app and the first MVP does not need multi-user collaboration.

### AI

AI is not required for P0.

P0 uses:

- Deterministic weekly summaries.
- Template-based clinician questions.
- Rule-based safety signposting.
- Native PDF rendering from structured data.

P1 AI, if validated, can be implemented behind an explicit opt-in and should use structured inputs only. Store model name, prompt version, input metrics hash, and generated result. Use deterministic analytics as the source of truth and the LLM only as a wording layer.

### PDF generation

The PDF should be generated from structured data, not from AI prose alone.

Recommended native implementation:

- Build a report view model from local SwiftData/Core Data entities.
- Render charts using native chart snapshots or simplified vector/table sections.
- Generate PDF pages with `UIGraphicsPDFRenderer` or PDFKit.
- Present the result using `ShareLink` or `UIActivityViewController`.

## 13. UX Principles

- Keep logging fast.
- Avoid making the user focus on tinnitus too much.
- Use calm, practical language.
- Show patterns only when useful.
- Prefer "what changed" over "what is wrong."
- Make export/report creation obvious.
- Never bury safety signposting behind chat, summaries, or automated insight screens.

## 14. Monetisation

### Recommended MVP pricing

Free:

- Onboarding profile
- Daily check-ins
- Trigger logs
- Spike logs
- 7-day history
- Basic sounds

Premium:

- Weekly extended insights
- Unlimited history
- Trigger association charts
- Audiologist PDF report
- Advanced sound favourites/history
- CSV export

Pricing to test:

- GBP 4.99 to GBP 7.99/month
- GBP 29 to GBP 49/year
- One-off audiologist report: GBP 7.99 to GBP 14.99

### Best first test

Start with a free app plus paid PDF report. This tests whether users value the audiologist companion use case before committing to a subscription-heavy model.

## 15. Success Metrics

### Activation

- Onboarding completion rate
- First check-in completion rate
- First spike log or first trigger log

### Engagement

- 7-day retention
- 30-day retention
- Average check-ins per active user per week
- Percentage of users with 14+ check-ins

### Value

- Weekly summary open rate
- Report generation rate
- Paid report conversion
- Premium conversion
- User-reported usefulness of insights

### Safety and trust

- Data deletion requests completed
- Privacy settings completion
- Number of red-flag signposts shown
- Safety signpost accuracy and user feedback

## 16. MVP Release Plan

### Milestone 1: Prototype

- Onboarding
- Daily check-in
- Trigger tracker
- Spike log
- Basic local charts

### Milestone 2: Report MVP

- PDF report template
- 7/14/30-day export
- Basic trend charts
- Trigger summary

### Milestone 3: Native Polish and Monetisation Prep

- Deterministic weekly metrics
- Native trend and report polish
- Safety wording review
- User feedback on summary usefulness

### Milestone 4: Payment Test

- Paid PDF export
- Premium feature gate
- Pricing A/B test manually or via simple paywall

## 17. Key Risks

### Risk: overclaiming medical value

Mitigation: keep claims to tracking, self-reflection, and appointment preparation.

### Risk: weak insights due to sparse data

Mitigation: minimum thresholds, confidence levels, and "not enough data" states.

### Risk: tracking increases symptom fixation

Mitigation: once-daily check-ins, gentle reminders, no aggressive streaks, optional weekly summaries.

### Risk: AI gives medical advice

Mitigation: do not ship AI in P0. If AI is added later, use deterministic analytics first, strict schemas, prompt guardrails, output filters, no medication advice, and explicit opt-in.

### Risk: privacy concerns

Mitigation: transparent data handling, local-first storage, export/delete, and no external AI/backend calls in P0.

### Risk: validated questionnaire licensing

Mitigation: use simple VAS scales in MVP, review TFI/THI/TQ permissions before embedding.

## 18. Open Questions

- What minimum iOS version should P0 support: iOS 17+ for SwiftData simplicity, or iOS 16+ for broader reach?
- Should users remain fully local-only until they explicitly enable cloud sync?
- Should the PDF report be paid from day one?
- Should the app target UK users first because of NICE/RNID-aligned content?
- Which crisis and medical signposting resources should be used by country?
- Should clinicians be interviewed before finalising the report template?
- Is AI worth adding after user testing, or do deterministic summaries/report exports satisfy the core job?
- Should audio discomfort mapping be the main differentiator in P0, or should it be tested as a separate prototype before merging into the tinnitus tracker?
- What headphone/device combinations can be supported with enough calibration confidence to write dB HL audiogram samples responsibly?

## 19. References

- JAMA Neurology: Global Prevalence and Incidence of Tinnitus: A Systematic Review and Meta-analysis. https://jamanetwork.com/journals/jamaneurology/fullarticle/2795168
- RNID: Prevalence of tinnitus. https://rnid.org.uk/get-involved/research-and-policy/facts-and-figures/prevalence-of-tinnitus/
- NICE NG155: Tinnitus assessment and management recommendations. https://www.nice.org.uk/guidance/ng155/chapter/Recommendations
- Apple Developer Documentation: HealthKit. https://developer.apple.com/documentation/healthkit
- Apple Developer Documentation: HealthKit sleep analysis. https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis
- Apple Developer Documentation: HealthKit headphone audio exposure. https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/3081272-headphoneaudioexposure
- Apple Developer Documentation: HKAudiogramSample. https://developer.apple.com/documentation/healthkit/hkaudiogramsample
- Apple Developer Documentation: HKAudiogramSampleType. https://developer.apple.com/documentation/healthkit/hkaudiogramsampletype
- Apple Developer Documentation: HKHealthStore save. https://developer.apple.com/documentation/healthkit/hkhealthstore/1614168-save
- ASHA: Degree of Hearing Loss. https://www.asha.org/public/hearing/Degree-of-Hearing-Loss/
- ASHA: The Audiogram. https://www.asha.org/public/hearing/Audiogram/
- Apple Developer Documentation: AVFoundation. https://developer.apple.com/av-foundation/
- Apple Developer Documentation: Accelerate. https://developer.apple.com/accelerate/
- MisoMind App Store listing. https://apps.apple.com/us/app/misomind-misophonia-relief/id6752851774
- Misophonia Trigger Tamer App Store listing. https://apps.apple.com/us/app/misophonia-trigger-tamer/id713542921
- Misophonia Institute: Trigger Tamer Apps. https://misophoniainstitute.org/the-trigger-tamer-apps/
- Spektral audio analyser. https://spektral.app/
- npj Digital Medicine: Global 10 year ecological momentary assessment and mobile sensing study on tinnitus and environmental sounds. https://www.nature.com/articles/s41746-025-01551-z
- Scientific Reports: Predicting the presence of tinnitus using ecological momentary assessments. https://www.nature.com/articles/s41598-023-36172-7
- ICO: Special category data guidance. https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/
- GOV.UK/MHRA: Software and AI as a medical device. https://www.gov.uk/government/publications/software-and-artificial-intelligence-ai-as-a-medical-device/software-and-artificial-intelligence-ai-as-a-medical-device
- DVA: Tinnitus Functional Index copyright and terms note. https://beta.dva.gov.au/about-us/dva-forms/tinnitus-functional-index-questionnaire-and-scoring-instructions
