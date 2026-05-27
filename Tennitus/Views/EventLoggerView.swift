import SwiftUI

struct EventLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @StateObject private var recorder = AudioEventRecorder()

    @State private var distress = 3.0
    @State private var loudness = 7.0
    @State private var triggerTags: Set<TriggerTag> = []
    @State private var recordingResult: AudioEventRecordingResult?
    @State private var sourceDetections: [SoundSourceDetection] = []
    @State private var isDetectingSource = false
    @State private var saveMessage: String?
    @State private var showingDiscardAlert = false

    var body: some View {
        ZStack {
            EventTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ClinicalStatusBar(
                    leftText: recorder.isRecording ? "● REC ACTIVE" : "● READY",
                    rightText: recordingResult?.analysis.dominantFrequencyHz != nil ? formatHz(recordingResult!.analysis.dominantFrequencyHz) : "-- Hz",
                    leftActive: recorder.isRecording
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        spectrumHero
                        subjectiveReadings
                        contextTags
                        saveButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .foregroundStyle(EventTheme.text)
        .preferredColorScheme(.dark)
        .onAppear {
            if !recorder.isRecording {
                Task { await recorder.start() }
            }
        }
        .onDisappear {
            recorder.stop()
        }
        .alert("Discard log?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                recorder.stop()
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("This will stop recording and discard this unsaved event.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTURE · LOG EVENT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(EventTheme.muted)
            Text("Analyze Ambient")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
            Text(recorder.isRecording ? "Capturing environment profile..." : "Audio captured.")
                .font(.subheadline)
                .foregroundStyle(EventTheme.muted)
        }
    }

    private var spectrumHero: some View {
        GlassPanel(padding: 20) {
            VStack(spacing: 16) {
                AnimatedSpectrumBars()

                Divider().background(EventTheme.border)
                    .padding(.vertical, 4)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AMBIENT PRESSURE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(EventTheme.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(recorder.loudnessDBFS.formatted(.number.precision(.fractionLength(1))))")
                                .font(.system(size: 32, design: .monospaced))
                            Text("dB")
                                .font(.system(size: 14))
                                .foregroundStyle(EventTheme.muted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("PEAK FREQ")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(EventTheme.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(peakHzValueString)
                                .font(.system(size: 20, design: .monospaced))
                                .foregroundStyle(EventTheme.primary)
                            Text("Hz")
                                .font(.system(size: 12))
                                .foregroundStyle(EventTheme.primary)
                        }
                    }
                }
            }
        }
    }

    private var peakHzValueString: String {
        let hz = recordingResult?.analysis.dominantFrequencyHz ?? 0
        if hz == 0 { return "--" }
        return "\(Int(hz))"
    }

    private var subjectiveReadings: some View {
        GlassPanel(padding: 20) {
            VStack(spacing: 20) {
                HStack {
                    Text("SUBJECTIVE READINGS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(EventTheme.muted)
                    Spacer()
                    Text("DRAG · SCROLL")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(EventTheme.muted)
                }

                HStack(spacing: 16) {
                    RotaryDialControl(
                        value: $loudness,
                        bounds: 0...10,
                        step: 1.0,
                        unit: "Loudness",
                        format: { val in "\(Int(val.rounded()))" },
                        size: 130
                    )
                    
                    RotaryDialControl(
                        value: $distress,
                        bounds: 0...10,
                        step: 1.0,
                        unit: "Distress",
                        format: { val in "\(Int(val.rounded()))" },
                        size: 130
                    )
                }
            }
        }
    }

    private var contextTags: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTEXT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(EventTheme.muted)

            let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(TriggerTag.allCases) { tag in
                    EventPill(title: tag.rawValue, active: triggerTags.contains(tag)) {
                        if triggerTags.contains(tag) {
                            triggerTags.remove(tag)
                        } else {
                            triggerTags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        VStack(spacing: 12) {
            Button {
                saveEvent()
            } label: {
                Text("SAVE DATA ENTRY")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1.0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(TennitusStyle.graphite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(EventTheme.background)
            }
            .buttonStyle(.plain)

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(EventTheme.primary)
            }
        }
        .padding(.top, 8)
    }



    private func saveEvent() {
        let description = [
            "Distress: \(Int(distress.rounded()))/10",
            "Felt loudness: \(Int(loudness.rounded()))/10",
            triggerTags.isEmpty ? "" : "Triggers: \(triggerTags.map(\.rawValue).sorted().joined(separator: ", "))"
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        if let recordingResult {
            let analysis = recordingResult.analysis
            let suggestion = SpectrumAnalyzer.localSuggestion(
                analysis: analysis,
                tinnitusMatchHz: store.profile.savedToneFrequencyHz ?? 4_000,
                description: description
            )

            let event = AudioEventLog(
                audioFilePath: recordingResult.audioFileURL?.path,
                selectedStartSeconds: 0,
                selectedEndSeconds: recordingResult.durationSeconds,
                userDescription: description,
                backgroundDescription: "",
                tinnitusMatchFrequencyHz: store.profile.savedToneFrequencyHz ?? 4_000,
                analysis: analysis,
                localSuggestion: suggestion,
                aiSuggestion: nil
            )
            store.save(event)
        }

        let spike = SpikeLog(
            loudness: Int(loudness.rounded()),
            distress: Int(distress.rounded()),
            context: "Logged event",
            triggers: triggerTags,
            notes: ""
        )
        store.save(spike)

        saveMessage = recordingResult != nil ? "Saved event with \(recordingResult!.analysis.dominantBandLabel) dominant band." : "Saved event without audio."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            dismiss()
        }
    }

    private var targetDescription: String {
        [triggerTags.map(\.rawValue).sorted().joined(separator: " ")]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatHz(_ hz: Double) -> String {
        guard hz > 0 else { return "Unknown" }
        return hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz.rounded())) Hz"
    }

    private func sourceDetectionSummary(_ detections: [SoundSourceDetection]) -> String {
        detections.prefix(3).map { detection in
            let marker = detection.matchedUserDescription ? "*" : ""
            return "\(marker)\(detection.label) \(Int((detection.confidence * 100).rounded()))%"
        }.joined(separator: ", ")
    }

    private func finalizeRecording() {
        guard recorder.isRecording else { return }
        recordingResult = recorder.stopAndAnalyse()
    }
}

private enum EventTheme {
    static let background = TennitusStyle.background
    static let surface = TennitusStyle.surface
    static let surface2 = TennitusStyle.surface2
    static let primary = TennitusStyle.accent
    static let accent = TennitusStyle.warning
    static let warning = TennitusStyle.destructive
    static let text = TennitusStyle.graphite
    static let muted = TennitusStyle.muted
    static let border = TennitusStyle.border
}

private struct EventStepContainer<Content: View>: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(EventTheme.primary)
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(EventTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(22)
        }
        .scrollIndicators(.hidden)
    }
}

private struct EventPill: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(active ? EventTheme.primary : EventTheme.surface2, in: Capsule())
                .foregroundStyle(active ? .black : EventTheme.text)
                .overlay(
                    Capsule().stroke(active ? EventTheme.primary : EventTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EventButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background((primary ? EventTheme.primary : EventTheme.surface).opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(primary ? EventTheme.background : EventTheme.text)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(EventTheme.border, lineWidth: primary ? 0 : 1)
            )
    }
}

private struct EventTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(EventTheme.border, lineWidth: 1)
            )
    }
}

private struct EventRecordingOrb: View {
    var isRecording: Bool
    var loudnessDBFS: Double

    var body: some View {
        let normalized = max(0, min(1, (loudnessDBFS + 60) / 60))
        ZStack {
            Circle()
                .fill(EventTheme.surface)
                .frame(width: 190, height: 190)
            Circle()
                .stroke(EventTheme.primary.opacity(isRecording ? 0.7 : 0.25), lineWidth: 14)
                .frame(width: 150 + CGFloat(normalized * 32), height: 150 + CGFloat(normalized * 32))
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(isRecording ? EventTheme.primary : EventTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActiveRecordingStrip: View {
    var elapsedSeconds: Int
    var loudnessDBFS: Double
    var stop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(EventTheme.warning.opacity(0.16))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(EventTheme.warning)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("REC ACTIVE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(EventTheme.warning)
                Text("\(elapsedSeconds)s · \(loudnessDBFS.formatted(.number.precision(.fractionLength(0)))) dBFS")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EventTheme.muted)
            }

            Spacer()

            Button(action: stop) {
                Label("Stop", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(EventTheme.surface2, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording and analyse")
        }
        .padding(12)
        .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EventTheme.border, lineWidth: 1)
        )
    }
}

private struct EventWaveform: View {
    var samples: [Float]

    var body: some View {
        GeometryReader { proxy in
            let bars = barValues(maxCount: 64)
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(EventTheme.primary.opacity(0.75))
                        .frame(width: max(2, proxy.size.width / CGFloat(max(1, bars.count)) - 2), height: max(5, CGFloat(value) * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func barValues(maxCount: Int) -> [Double] {
        guard !samples.isEmpty else { return [] }
        let step = max(1, samples.count / maxCount)
        return stride(from: 0, to: samples.count, by: step).map { index in
            let end = min(samples.count, index + step)
            let slice = samples[index..<end]
            let peak = slice.map { abs(Double($0)) }.max() ?? 0
            return max(0.05, min(1, peak * 8))
        }
    }
}

private struct EventRangeSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EventTheme.muted)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(2))))s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EventTheme.text)
            }
            Slider(value: $value, in: safeRange, step: 0.05)
                .tint(EventTheme.primary)
        }
    }

    private var safeRange: ClosedRange<Double> {
        if range.upperBound > range.lowerBound {
            return range
        }
        return range.lowerBound...(range.lowerBound + 0.05)
    }
}

private struct EventSpectrumSummary: View {
    var title = "Spectrum clues"
    var analysis: AudioAnalysisSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EventTheme.text)
            EventSummaryRow(label: "Peak frequency", value: formatHz(analysis.dominantFrequencyHz))
            if !analysis.topFrequencyPeaks.isEmpty {
                EventSummaryRow(label: "Top peaks", value: analysis.topFrequencyPeaks.prefix(4).map { formatHz($0.frequencyHz) }.joined(separator: ", "))
            }
            EventSummaryRow(label: "Dominant band", value: analysis.dominantBandLabel)
            EventSummaryRow(label: "Range", value: analysis.sensitiveRangeLabel)
        }
        .padding(14)
        .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatHz(_ hz: Double) -> String {
        guard hz > 0 else { return "Unknown" }
        return hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz.rounded())) Hz"
    }
}

private struct EventTargetSoundCard: View {
    var match: TargetSoundMatch
    var detections: [SoundSourceDetection]
    var isDetectingSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target sound")
                        .font(.headline)
                    Text(match.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EventTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int((match.score * 100).rounded()))%")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(EventTheme.primary)
                    Text(match.confidence)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EventTheme.muted)
                }
            }

            EventSummaryRow(label: "STFT window", value: match.timeRangeLabel)
            EventSummaryRow(label: "Peak", value: formatHz(match.dominantFrequencyHz))
            EventSummaryRow(label: "Peaks", value: match.topFrequencyPeaks.prefix(4).map { formatHz($0.frequencyHz) }.joined(separator: ", "))

            if isDetectingSource {
                EventSummaryRow(label: "Classifier", value: "Detecting source...")
            } else if !detections.isEmpty {
                EventSummaryRow(label: "Labels", value: detectionSummary)
            }

            ForEach(match.rationale.prefix(2), id: \.self) { rationale in
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(EventTheme.muted)
            }
        }
        .padding(14)
        .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detectionSummary: String {
        detections.prefix(3).map { detection in
            let marker = detection.matchedUserDescription ? "*" : ""
            return "\(marker)\(detection.label) \(Int((detection.confidence * 100).rounded()))%"
        }.joined(separator: ", ")
    }

    private func formatHz(_ hz: Double) -> String {
        guard hz > 0 else { return "Unknown" }
        return hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz.rounded())) Hz"
    }
}

private struct EventSummaryRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EventTheme.muted)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(EventTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
