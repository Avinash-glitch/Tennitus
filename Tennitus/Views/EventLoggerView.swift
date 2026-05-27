import SwiftUI

struct EventLoggerView: View {
    private enum Step: Int, CaseIterable {
        case audio
        case distress
        case loudness
        case context
        case spectrum
        case review

        var title: String {
            switch self {
            case .audio: "Record"
            case .spectrum: "Spectrum"
            case .distress: "Distress"
            case .loudness: "Loudness"
            case .context: "Context"
            case .review: "Review"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @StateObject private var recorder = AudioEventRecorder()

    @State private var step: Step = .audio
    @State private var skippedAudio = false
    @State private var distress = 5.0
    @State private var loudness = 5.0
    @State private var context = ""
    @State private var notes = ""
    @State private var triggerTags: Set<TriggerTag> = []
    @State private var recordingResult: AudioEventRecordingResult?
    @State private var selectedStartSeconds = 0.0
    @State private var selectedEndSeconds = 0.0
    @State private var selectedAnalysis: AudioAnalysisSummary?
    @State private var spectrumSnapshots: [SpectrumSnapshot] = []
    @State private var selectedSnapshotID: UUID?
    @State private var sourceDetections: [SoundSourceDetection] = []
    @State private var isDetectingSource = false
    @State private var saveMessage: String?
    @State private var showingDiscardAlert = false

    private var hasUnsavedData: Bool {
        if recorder.isRecording { return true }
        if recordingResult != nil { return true }
        if distress != 5.0 || loudness != 5.0 { return true }
        if !context.isEmpty || !notes.isEmpty { return true }
        if !triggerTags.isEmpty { return true }
        return false
    }

    private func handleDismiss() {
        if hasUnsavedData {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            EventTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                progress
                currentStep
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                footer
            }
        }
        .foregroundStyle(EventTheme.text)
        .preferredColorScheme(.dark)
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
        HStack {
            Button {
                handleDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.headline)
                .foregroundStyle(EventTheme.text)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(EventTheme.surface, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Log event")
                .font(.headline)

            Spacer()

            Text("\(step.rawValue + 1)/\(Step.allCases.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(EventTheme.muted)
                .frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? EventTheme.primary : EventTheme.surface)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .audio:
            audioStep
        case .spectrum:
            spectrumStep
        case .distress:
            scaleStep(
                eyebrow: "DISTRESS",
                title: "How distressing is it right now?",
                subtitle: "This captures the emotional load of the event.",
                value: $distress,
                unit: "/ 10"
            )
        case .loudness:
            scaleStep(
                eyebrow: "LOUDNESS",
                title: "How loud does it feel?",
                subtitle: "This is your perceived tinnitus loudness, not microphone loudness.",
                value: $loudness,
                unit: "/ 10"
            )
        case .context:
            contextStep
        case .review:
            reviewStep
        }
    }

    private func scaleStep(
        eyebrow: String,
        title: String,
        subtitle: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        EventStepContainer(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            VStack(spacing: 28) {
                if recorder.isRecording {
                    ActiveRecordingStrip(elapsedSeconds: recorder.elapsedSeconds, loudnessDBFS: recorder.loudnessDBFS) {
                        finalizeRecording()
                    }
                }

                RotaryDialControl(
                    value: value,
                    bounds: 0...10,
                    step: 1.0,
                    unit: unit,
                    format: { val in "\(Int(val.rounded()))" }
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
    }

    private var contextStep: some View {
        EventStepContainer(
            eyebrow: "CONTEXT",
            title: "What was happening?",
            subtitle: recorder.isRecording ? "Keep recording while you describe what is happening." : "Add the setting and likely triggers for this sound."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if recorder.isRecording {
                    ActiveRecordingStrip(elapsedSeconds: recorder.elapsedSeconds, loudnessDBFS: recorder.loudnessDBFS) {
                        finalizeRecording()
                    }
                }

                TextField("e.g. cafe, train, headphones, quiet room", text: $context, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(EventTextFieldStyle())

                TextField("Optional note", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(EventTextFieldStyle())

                Text("Likely triggers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EventTheme.muted)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
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
    }

    private var audioStep: some View {
        EventStepContainer(
            eyebrow: "FIRST QUESTION",
            title: recorder.isRecording ? "Recording environment" : "Record audio so the model can find clues?",
            subtitle: "A short recording lets Tennitus analyse loudness, frequency bands, peaks, and sharp sounds. Raw audio stays local for this MVP."
        ) {
            VStack(spacing: 18) {
                EventRecordingOrb(isRecording: recorder.isRecording, loudnessDBFS: recorder.loudnessDBFS)

                if recorder.isRecording {
                    Text("\(recorder.elapsedSeconds)s")
                        .font(.title2.monospacedDigit().weight(.semibold))
                } else if let recordingResult {
                    Text("Recorded \(recordingResult.durationSeconds.formatted(.number.precision(.fractionLength(1))))s")
                        .font(.headline)
                } else {
                    Text("Tap record when the event is happening.")
                        .font(.subheadline)
                        .foregroundStyle(EventTheme.muted)
                }

                if !recorder.recentSamples.isEmpty {
                    EventWaveform(samples: recorder.recentSamples)
                        .frame(height: 88)
                }

                if let error = recorder.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(EventTheme.warning)
                }

                Button {
                    toggleRecording()
                } label: {
                    Label(recorder.isRecording ? "Stop now and analyse" : recordingResult == nil ? "Start recording" : "Record again", systemImage: recorder.isRecording ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(EventButtonStyle(primary: true))

                if recorder.isRecording {
                    Text("You can tap Next and keep recording while you complete the log.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EventTheme.primary)
                        .multilineTextAlignment(.center)
                }

                if !recorder.isRecording && recordingResult == nil {
                    Button {
                        skippedAudio = true
                        step = .distress
                    } label: {
                        Label("Skip audio", systemImage: "forward.fill")
                    }
                    .buttonStyle(EventButtonStyle(primary: false))
                }
            }
        }
    }

    private var spectrumStep: some View {
        EventStepContainer(
            eyebrow: "SPECTRUM",
            title: "Mark the part that hurt",
            subtitle: "Drag the range to analyse the exact sound, then use the peaks and spectrum as clues."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let recordingResult {
                    WaveformSelectionView(
                        samples: recordingResult.samples,
                        selectedStart: selectedStartSeconds,
                        selectedEnd: selectedEndSeconds,
                        duration: recordingResult.durationSeconds,
                        highlightedStart: selectedSnapshot?.startSeconds,
                        highlightedEnd: selectedSnapshot.map { $0.startSeconds + $0.durationSeconds }
                    )
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 10) {
                        EventRangeSlider(
                            title: "Start",
                            value: $selectedStartSeconds,
                            range: 0...max(0.01, selectedEndSeconds - 0.1)
                        )
                        EventRangeSlider(
                            title: "End",
                            value: $selectedEndSeconds,
                            range: min(recordingResult.durationSeconds, selectedStartSeconds + 0.1)...max(0.1, recordingResult.durationSeconds)
                        )
                    }

                    Button {
                        reanalyseSelectedSegment()
                    } label: {
                        Label("Analyse selected part", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(EventButtonStyle(primary: true))

                    let analysis = displayedSpectrumAnalysis(recordingResult: recordingResult)
                    EventSpectrumSummary(
                        title: selectedSnapshot == nil ? "Selection spectrum" : "Frame dB curve",
                        analysis: analysis
                    )

                    if !spectrumSnapshots.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("STFT window")
                                    .font(.headline)
                                    .foregroundStyle(EventTheme.text)
                                Spacer()
                                Text(selectedSnapshotRangeLabel)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(EventTheme.muted)
                            }
                            Slider(
                                value: spectrumSnapshotIndexBinding,
                                in: 0...Double(max(0, spectrumSnapshots.count - 1)),
                                step: 1
                            )
                            .tint(EventTheme.primary)
                            SpectrogramHeatmapView(snapshots: spectrumSnapshots, selectedSnapshotID: $selectedSnapshotID)
                                .colorScheme(.light)
                        }
                        .padding(14)
                        .background(EventTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    SpectrumCurveView(
                        analysis: analysis,
                        tinnitusHz: store.profile.savedToneFrequencyHz,
                        bothersomeHz: analysis.dominantFrequencyHz > 0 ? analysis.dominantFrequencyHz : nil,
                        notchHz: nil
                    )
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .colorScheme(.light)
                } else {
                    if recorder.isRecording {
                        ActiveRecordingStrip(elapsedSeconds: recorder.elapsedSeconds, loudnessDBFS: recorder.loudnessDBFS) {
                            finalizeRecording()
                        }
                        Text("Stop the recording to unlock spectrum review.")
                            .font(.subheadline)
                            .foregroundStyle(EventTheme.muted)
                    } else {
                        Text("Record audio first to see the spectrum.")
                            .font(.subheadline)
                            .foregroundStyle(EventTheme.warning)
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        EventStepContainer(
            eyebrow: "REVIEW",
            title: "Save this event?",
            subtitle: recordingResult == nil ? "This event will save your symptom ratings and context without audio clues." : "The event combines your answers with the recorded spectrum analysis."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                EventSummaryRow(label: "Distress", value: "\(Int(distress.rounded()))/10")
                EventSummaryRow(label: "Loudness", value: "\(Int(loudness.rounded()))/10")
                EventSummaryRow(label: "Context", value: context.isEmpty ? "Not added" : context)
                EventSummaryRow(label: "Triggers", value: triggerTags.isEmpty ? "None selected" : triggerTags.map(\.rawValue).sorted().joined(separator: ", "))

                if let analysis = reviewAnalysis {
                    Divider().overlay(EventTheme.border)
                    EventSummaryRow(label: "Peak frequency", value: formatHz(analysis.dominantFrequencyHz))
                    if !analysis.topFrequencyPeaks.isEmpty {
                        EventSummaryRow(label: "Top peaks", value: analysis.topFrequencyPeaks.prefix(3).map { formatHz($0.frequencyHz) }.joined(separator: ", "))
                    }
                    if let match = analysis.targetSoundMatches.first {
                        EventTargetSoundCard(match: match, detections: analysis.sourceDetections, isDetectingSource: isDetectingSource)
                    } else if !isDetectingSource && analysis.sourceDetections.isEmpty && !targetDescription.isEmpty {
                        Text("No confident source label found; showing frequency clues instead.")
                            .font(.footnote)
                            .foregroundStyle(EventTheme.warning)
                    }
                    if isDetectingSource {
                        EventSummaryRow(label: "Classifier", value: "Detecting source...")
                    } else if !analysis.sourceDetections.isEmpty {
                        EventSummaryRow(label: "Classifier labels", value: sourceDetectionSummary(analysis.sourceDetections))
                    }
                    EventSummaryRow(label: "Dominant band", value: analysis.dominantBandLabel)
                    EventSummaryRow(label: "Sensitive range", value: analysis.sensitiveRangeLabel)
                    EventSummaryRow(label: "Peak", value: "\(analysis.peakDBFS.formatted(.number.precision(.fractionLength(1)))) dBFS")
                    TriggerScoreCard(score: TriggerWeightingEngine.calculate(store: store, analysis: analysis))
                        .colorScheme(.light)
                } else {
                    Text("No audio recording attached. Audio clues like dominant band and sensitive range will be unavailable.")
                        .font(.footnote)
                        .foregroundStyle(skippedAudio ? EventTheme.muted : EventTheme.warning)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(EventTheme.primary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                previous()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(EventButtonStyle(primary: false))
            .disabled(step == .audio)

            Button {
                nextOrSave()
            } label: {
                Label(primaryFooterTitle, systemImage: step == .review ? "square.and.arrow.down" : "chevron.right")
            }
            .buttonStyle(EventButtonStyle(primary: true))
            .disabled(step == .audio && recordingResult == nil && !skippedAudio && !recorder.isRecording)
        }
        .padding(20)
    }

    private var primaryFooterTitle: String {
        if step == .review { return "Save event" }
        if step == .audio && recorder.isRecording { return "Continue logging" }
        if step == .context && recorder.isRecording { return "Stop and review spectrum" }
        return "Next"
    }

    private var reviewAnalysis: AudioAnalysisSummary? {
        guard let recordingResult else { return nil }
        let base = selectedAnalysis ?? recordingResult.analysis
        let description = targetDescription
        guard !description.isEmpty else { return base }
        return SpectrumAnalyzer.analyzeTargeted(
            samples: recordingResult.samples,
            sampleRate: recordingResult.sampleRate,
            startSeconds: selectedStartSeconds,
            endSeconds: selectedEndSeconds,
            description: description
        ).withSourceDetections(sourceDetections)
    }

    private func toggleRecording() {
        if recorder.isRecording {
            finalizeRecording()
        } else {
            recordingResult = nil
            selectedAnalysis = nil
            spectrumSnapshots = []
            selectedSnapshotID = nil
            sourceDetections = []
            selectedStartSeconds = 0
            selectedEndSeconds = 0
            skippedAudio = false
            Task {
                await recorder.start()
            }
        }
    }

    private func previous() {
        guard let previousStep = Step(rawValue: step.rawValue - 1) else { return }
        step = previousStep
    }

    private func nextOrSave() {
        if step == .review {
            if recorder.isRecording {
                finalizeRecording()
            }
            saveEvent()
            return
        }

        if step == .audio && recorder.isRecording {
            step = .distress
            return
        }

        if step == .context && recorder.isRecording {
            finalizeRecording()
            step = .spectrum
            return
        }

        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
        if nextStep == .review {
            detectDescribedSource()
        }
    }

    private func finalizeRecording() {
        guard recorder.isRecording else { return }
        recordingResult = recorder.stopAndAnalyse()
        selectedAnalysis = recordingResult?.analysis
        refreshSpectrumSnapshots()
        sourceDetections = []
        selectedStartSeconds = 0
        selectedEndSeconds = recordingResult?.durationSeconds ?? 0
        skippedAudio = false
    }

    private func reanalyseSelectedSegment() {
        guard let recordingResult else { return }
        let start = max(0, min(selectedStartSeconds, recordingResult.durationSeconds))
        let end = max(start + 0.05, min(selectedEndSeconds, recordingResult.durationSeconds))
        selectedStartSeconds = start
        selectedEndSeconds = end
        selectedAnalysis = SpectrumAnalyzer.analyze(
            samples: recordingResult.samples,
            sampleRate: recordingResult.sampleRate,
            startSeconds: start,
            endSeconds: end
        )
        refreshSpectrumSnapshots()
        sourceDetections = []
        if !targetDescription.isEmpty {
            detectDescribedSource()
        }
    }

    private func refreshSpectrumSnapshots() {
        guard let recordingResult else {
            spectrumSnapshots = []
            selectedSnapshotID = nil
            return
        }

        let start = max(0, min(selectedStartSeconds, recordingResult.durationSeconds))
        let end = max(start + 0.05, min(selectedEndSeconds > 0 ? selectedEndSeconds : recordingResult.durationSeconds, recordingResult.durationSeconds))
        guard recordingResult.sampleRate > 0, end > start else {
            spectrumSnapshots = []
            selectedSnapshotID = nil
            return
        }

        let lower = max(0, Int((start * recordingResult.sampleRate).rounded(.down)))
        let upper = min(recordingResult.samples.count, Int((end * recordingResult.sampleRate).rounded(.up)))
        guard upper - lower >= 512 else {
            spectrumSnapshots = []
            selectedSnapshotID = nil
            return
        }

        spectrumSnapshots = SpectrumAnalyzer.stftSnapshots(
            samples: Array(recordingResult.samples[lower..<upper]),
            sampleRate: recordingResult.sampleRate,
            windowSeconds: 0.5,
            hopSeconds: 0.5,
            startOffsetSeconds: start
        )
        selectedSnapshotID = spectrumSnapshots.first?.id
    }

    private func detectDescribedSource() {
        guard !isDetectingSource, let url = recordingResult?.audioFileURL else { return }
        let description = targetDescription
        guard !description.isEmpty else { return }

        isDetectingSource = true
        Task {
            let detections = await SoundSourceDetectionService.detect(audioFileURL: url, userDescription: description)
            await MainActor.run {
                sourceDetections = detections
                isDetectingSource = false
            }
        }
    }

    private func saveEvent() {
        let description = [
            "Distress: \(Int(distress.rounded()))/10",
            "Felt loudness: \(Int(loudness.rounded()))/10",
            notes,
            triggerTags.isEmpty ? "" : "Triggers: \(triggerTags.map(\.rawValue).sorted().joined(separator: ", "))"
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        if let recordingResult {
            let analysis = reviewAnalysis ?? selectedAnalysis ?? recordingResult.analysis
            let suggestion = SpectrumAnalyzer.localSuggestion(
                analysis: analysis,
                tinnitusMatchHz: store.profile.savedToneFrequencyHz ?? 4_000,
                description: "\(context) \(description)"
            )

            let event = AudioEventLog(
                audioFilePath: recordingResult.audioFileURL?.path,
                selectedStartSeconds: selectedStartSeconds,
                selectedEndSeconds: selectedEndSeconds,
                userDescription: description,
                backgroundDescription: context,
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
            context: context.isEmpty ? "Logged event" : context,
            triggers: triggerTags,
            notes: notes
        )
        store.save(spike)

        saveMessage = (selectedAnalysis ?? recordingResult?.analysis).map { "Saved event with \($0.dominantBandLabel) dominant band." } ?? "Saved event without audio."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            dismiss()
        }
    }

    private var targetDescription: String {
        [context, notes, triggerTags.map(\.rawValue).sorted().joined(separator: " ")]
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

    private func displayedSpectrumAnalysis(recordingResult: AudioEventRecordingResult) -> AudioAnalysisSummary {
        selectedSnapshot?.analysis ?? selectedAnalysis ?? recordingResult.analysis
    }

    private var selectedSnapshot: SpectrumSnapshot? {
        guard let selectedSnapshotID else { return spectrumSnapshots.first }
        return spectrumSnapshots.first { $0.id == selectedSnapshotID } ?? spectrumSnapshots.first
    }

    private var selectedSnapshotRangeLabel: String {
        guard let selectedSnapshot else { return "No window" }
        return "\(selectedSnapshot.startSeconds.formatted(.number.precision(.fractionLength(1))))-\((selectedSnapshot.startSeconds + selectedSnapshot.durationSeconds).formatted(.number.precision(.fractionLength(1))))s"
    }

    private var selectedSnapshotIndex: Int {
        guard let selectedSnapshotID else { return 0 }
        return spectrumSnapshots.firstIndex { $0.id == selectedSnapshotID } ?? 0
    }

    private var spectrumSnapshotIndexBinding: Binding<Double> {
        Binding(
            get: { Double(selectedSnapshotIndex) },
            set: { newValue in
                let index = max(0, min(spectrumSnapshots.count - 1, Int(newValue.rounded())))
                selectedSnapshotID = spectrumSnapshots.indices.contains(index) ? spectrumSnapshots[index].id : spectrumSnapshots.first?.id
            }
        )
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
