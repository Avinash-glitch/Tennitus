# Xcode and TestFlight Checklist

Use this when you build Tennitus locally in Xcode and push to TestFlight.

## 1. Open Project

Open:

```text
Tennitus.xcodeproj
```

Confirm the active scheme is:

```text
Tennitus
```

The repo includes a shared scheme at:

```text
Tennitus.xcodeproj/xcshareddata/xcschemes/Tennitus.xcscheme
```

## 2. Signing

In Xcode:

- Select the Tennitus target.
- Go to **Signing & Capabilities**.
- Confirm your Apple Developer team is selected.
- Confirm the bundle identifier is unique for your account.
- Confirm HealthKit capability is enabled.

The project already includes:

```text
Tennitus/Tennitus.entitlements
```

with HealthKit enabled.

## 3. Info Plist Permissions

Confirm generated Info.plist includes:

- `NSMicrophoneUsageDescription`
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

These are required for:

- sound event recording
- Apple Health audiogram save
- future HealthKit imports

## 4. AI Proxy For TestFlight

Do not ship a TestFlight build that relies on users entering an AI provider key. The iOS app should call the backend proxy, and the backend should hold the provider key.

For local backend testing, add this to the repo-root `.env` file:

```text
GEMINI_API_KEY=your_server_side_key
GEMINI_MODEL=gemini-2.5-flash
```

The backend proxy lives in:

```text
backend/openai_proxy
```

For TestFlight, deploy the proxy to an HTTPS host and set the Xcode build setting `TENNITUS_AI_PROXY_URL` to the full endpoint, for example:

```text
https://your-proxy.example.com/v1/comfort-session
```

## 5. Device Testing

Test on a real iPhone because these features are limited or unreliable in Simulator:

- microphone input
- audio session routing
- HealthKit authorization
- Apple Health audiogram save
- TestFlight entitlements

Recommended test flow:

1. Launch app.
2. Go to **Lab**.
3. Play low-volume tinnitus tone match.
4. Record a 5-10 second sound event.
5. Select the bothersome segment.
6. Re-analyse the selection.
7. Play the selected clip.
8. Add labels, reaction intensity, description, and background.
9. Open Spectrum Review.
10. Apply the local notch preview and A/B original versus notched audio.
11. Generate local comfort suggestion.
12. Run AI proxy analysis.
13. Save event.
14. Generate report.
15. Go to Reports -> Indicative audiogram screen.
16. Adjust threshold sliders.
17. Generate audiogram PDF.
18. Save to Apple Health.

## 6. TestFlight Build

Before archiving:

- Increment build number.
- Check signing.
- Use Release configuration.
- Test on device once from Xcode.

Archive:

```text
Product -> Archive
```

Then:

```text
Distribute App -> App Store Connect -> Upload
```

## 7. App Review / Beta Review Wording

Avoid claiming:

- diagnosis
- treatment
- cure
- medical-grade hearing test
- prevention of hearing damage

Use:

- comfort session
- indicative screening
- user-reported patterns
- uncalibrated phone microphone
- audiologist-ready report

Suggested beta description:

```text
Tennitus is a local-first tinnitus and sound-sensitivity companion. It lets users record sound events, inspect frequency patterns, log tinnitus context, generate comfort-session suggestions, and export appointment-ready reports. Audiogram features are indicative screening tools and are not a clinical diagnosis.
```
