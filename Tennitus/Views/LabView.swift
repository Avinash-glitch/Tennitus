import SwiftUI

struct LabView: View {
    private enum LabRoute {
        case home
        case tone
        case record
        case review
        case spectrum
        case ai
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tonePlayer = TinnitusTonePlayer()
    @StateObject private var recorder = AudioEventRecorder()
    @StateObject private var playbackPlayer = RecordingPlaybackPlayer()


    @State private var route: LabRoute = .home
    @State private var matchLowHz = 125.0
    @State private var matchHighHz = 12_000.0
    @State private var toneSaveMessage: String?
    @State private var userDescription = ""
    @State private var backgroundDescription = ""
    @State private var selectedLabels: Set<String> = []
    @State private var reactionIntensity = 6.0
    @State private var recordingResult: AudioEventRecordingResult?
    @State private var latestAnalysis: AudioAnalysisSummary?
    @State private var latestRecordingURL: URL?
    @State private var recordingDurationSeconds = 0.0
    @State private var selectedStartSeconds = 0.0
    @State private var selectedEndSeconds = 0.0
    @State private var spectrumSnapshots: [SpectrumSnapshot] = []
    @State private var selectedSpectrumSnapshotID: UUID?
    @State private var waveformZoom = 1.0
    @State private var notchHz = 4_000.0
    @State private var notchedSamples: [Float] = []
    @State private var notchedURL: URL?
    @State private var notchedAnalysis: AudioAnalysisSummary?
    @State private var compareNotch = false
    @State private var localSuggestion = ComfortSessionSuggestion.empty
    @State private var aiSuggestion: ComfortSessionSuggestion?
    @State private var isAnalysingWithAI = false
    @State private var aiError: String?
    @State private var saveMessage: String?
    @State private var sensitivitySliderValue = 0.5
    
    private var toneDialSensitivity: Double {
        if sensitivitySliderValue <= 0.5 {
            return 1 + (sensitivitySliderValue / 0.5) * 99.0
        } else {
            return 100 + ((sensitivitySliderValue - 0.5) / 0.5) * 400.0
        }
    }

    private let labelOptions = ["Sharp", "Sibilant", "Pulsing", "Metallic", "Crowded", "Hissing"]

    var body: some View {
        AppScreen {
            switch route {
            case .home:
                homeView
            case .tone:
                toneMatchView
            case .record:
                recordView
            case .review:
                reviewView
            case .spectrum:
                spectrumView
            case .ai:
                aiView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            tonePlayer.stop()
            recorder.stop()
            playbackPlayer.stop()
        }
        .onAppear {
            loadToneProfile()
        }
    }

    private var homeView: some View {
        Group {
            AppHeader(
                eyebrow: "Acoustic tools",
                title: "Lab",
                subtitle: "Match your tinnitus tone, capture bothering sounds, and review spectrum patterns."
            )

            AppSection("Tools") {
                AppCard {
                    toolRow(
                        icon: "waveform",
                        title: "Tinnitus Tone Match",
                        subtitle: savedToneSubtitle,
                        tint: TennitusStyle.primary
                    ) {
                        route = .tone
                    }
                    divider
                    toolRow(
                        icon: "mic.circle",
                        title: "Log Sound Event",
                        subtitle: "Record 5-30s · live waveform + spectrum",
                        tint: TennitusStyle.warning
                    ) {
                        route = .record
                    }
                    divider
                    toolRow(
                        icon: "chart.xyaxis.line",
                        title: "Spectrum Review",
                        subtitle: latestAnalysis == nil ? "No recording yet" : "Last recording ready · A/B notch filter",
                        tint: TennitusStyle.accent
                    ) {
                        if latestAnalysis != nil {
                            route = .spectrum
                        }
                    }
                }
            }

            if let latestAnalysis {
                AppSection("Current Draft") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                StatBlock(label: "Dominant", value: latestAnalysis.dominantBandLabel, unit: nil)
                                Spacer()
                                StatBlock(label: "Selected", value: "\(formatTime(selectedStartSeconds))-\(formatTime(selectedEndSeconds))", unit: nil)
                            }
                            MiniWaveView(color: TennitusStyle.primary)
                            Button {
                                route = .review
                            } label: {
                                Label("Continue review", systemImage: "arrow.right.circle.fill")
                            }
                            .buttonStyle(AppButtonStyle(variant: .primary))
                        }
                    }
                }
            }

            if !store.audioEvents.isEmpty {
                AppSection("Recent Events") {
                    AppCard {
                        ForEach(Array(store.audioEvents.prefix(4).enumerated()), id: \.element.id) { index, event in
                            recentEventRow(event)
                            if index < min(store.audioEvents.count, 4) - 1 {
                                divider
                            }
                        }
                    }
                }
            }

            AppSection {
                SafetyNote(text: "Use the lab at comfortable volume only. The app helps track patterns and prepare reports, but it does not diagnose, treat, or cure tinnitus.")
            }
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            } label: {
                Text("BACK TO HOME")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(TennitusStyle.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(TennitusStyle.border, lineWidth: 1))
                    .foregroundStyle(TennitusStyle.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var toneMatchView: some View {
        Group {
            BackHeader(parent: "Lab", title: "Tone Match", actionTitle: "Done", onBack: {
                tonePlayer.stop()
                route = .home
            }, onAction: {
                tonePlayer.stop()
                route = .home
            })

            AppSection {
                AppCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Tinnitus Tone")
                                .font(.headline)
                                .foregroundStyle(TennitusStyle.graphite)
                            Spacer()
                            Circle()
                                .fill(tonePlayer.isPlaying ? TennitusStyle.accent : TennitusStyle.border)
                                .frame(width: 12, height: 12)
                        }

                        HStack(spacing: 20) {
                            Spacer()
                            
                            RotaryDialControl(
                                value: $tonePlayer.frequencyHz,
                                bounds: matchLowHz...matchHighHz,
                                step: toneDialSensitivity,
                                unit: "Hz",
                                format: { val in "\(Int(val.rounded()))" }
                            )
                            
                            VStack(spacing: 8) {
                                Text("Fast")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TennitusStyle.muted)
                                    
                                Slider(value: $sensitivitySliderValue, in: 0...1)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 20, height: 160)
                                
                                Text("Fine")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TennitusStyle.muted)
                            }
                            .frame(width: 40)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Waveform")
                                .font(.subheadline.weight(.medium))

                            HStack(spacing: 8) {
                                ForEach(ToneWaveform.allCases) { waveform in
                                    PillButton(title: waveform.rawValue, active: tonePlayer.waveform == waveform) {
                                        tonePlayer.waveform = waveform
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Matching band filter")
                                Spacer()
                                Text("\(formatHz(matchLowHz))-\(formatHz(matchHighHz))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(TennitusStyle.muted)
                            }
                            .font(.subheadline.weight(.medium))

                            HStack(spacing: 8) {
                                PillButton(title: "Low", active: matchLowHz == 125 && matchHighHz == 1_000) {
                                    setMatchBand(low: 125, high: 1_000)
                                }
                                PillButton(title: "Mid", active: matchLowHz == 500 && matchHighHz == 4_000) {
                                    setMatchBand(low: 500, high: 4_000)
                                }
                                PillButton(title: "High", active: matchLowHz == 2_000 && matchHighHz == 8_000) {
                                    setMatchBand(low: 2_000, high: 8_000)
                                }
                                PillButton(title: "Full", active: matchLowHz == 125 && matchHighHz == 12_000) {
                                    setMatchBand(low: 125, high: 12_000)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lower edge")
                                    .font(.caption)
                                    .foregroundStyle(TennitusStyle.muted)
                                Slider(value: lowerBandBinding, in: 125...11_000, step: 25)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Upper edge")
                                    .font(.caption)
                                    .foregroundStyle(TennitusStyle.muted)
                                Slider(value: upperBandBinding, in: 250...12_000, step: 25)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                adjustTone(by: -50)
                            } label: {
                                Label("50 Hz", systemImage: "minus")
                            }
                            .buttonStyle(AppButtonStyle(variant: .secondary))

                            Button {
                                adjustTone(by: 50)
                            } label: {
                                Label("50 Hz", systemImage: "plus")
                            }
                            .buttonStyle(AppButtonStyle(variant: .secondary))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Volume")
                                Spacer()
                                Text("\(Int(tonePlayer.volume * 100))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            Slider(value: $tonePlayer.volume, in: 0...0.25, step: 0.01)
                        }

                        HStack(spacing: 10) {
                            Button {
                                tonePlayer.toggle()
                            } label: {
                                Label(tonePlayer.isPlaying ? "Stop" : "Play Tone", systemImage: tonePlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            }
                            .buttonStyle(AppButtonStyle(variant: tonePlayer.isPlaying ? .danger : .primary))

                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    saveToneMatchToProfile()
                                }
                            } label: {
                                Label("Save Match", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(AppButtonStyle(variant: .primary))
                        }

                        if let toneSaveMessage {
                            Text(toneSaveMessage)
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.primary)
                        }
                    }
                }
            }

            AppSection {
                SafetyNote(text: "Tone matching should be barely audible and comfortable. Stop immediately if the sound feels unpleasant.")
            }
        }
    }

    private var recordView: some View {
        Group {
            BackHeader(parent: "Lab", title: "Log Sound Event", actionTitle: nil, onBack: {
                recorder.stop()
                route = .home
            }, onAction: nil)

            AppSection {
                AppCard(padding: 18) {
                    VStack(spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recorder.isRecording ? "Recording" : "Ready")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(TennitusStyle.graphite)
                                Text("\(recorder.elapsedSeconds)s of 30s")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(recorder.loudnessDBFS.formatted(.number.precision(.fractionLength(1)))) dBFS")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ZStack {
                            Circle()
                                .fill((recorder.isRecording ? TennitusStyle.warning : TennitusStyle.primary).opacity(0.12))
                                .frame(width: 150, height: 150)
                            Button {
                                if recorder.isRecording {
                                    stopAndAnalyse()
                                    route = .review
                                } else {
                                    clearDraft(keepDescriptions: true)
                                    Task { await recorder.start() }
                                    route = .review
                                }
                            } label: {
                                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 96, height: 96)
                                    .background(recorder.isRecording ? TennitusStyle.warning : TennitusStyle.primary, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input level")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ProgressView(value: levelProgress)
                                .tint(TennitusStyle.primary)
                        }

                        WaveformSelectionView(
                            samples: recorder.recentSamples,
                            selectedStart: 0,
                            selectedEnd: 0,
                            duration: 0
                        )
                        .frame(height: 110)

                        if recorder.permissionDenied {
                            Text("Microphone permission is needed for sound-event analysis.")
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.warning)
                        }

                        if let error = recorder.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.warning)
                        }
                    }
                }
            }

            AppSection {
                SafetyNote(text: "Record your environment, not private conversations. Raw audio stays local for this POC. The AI receives only numeric spectrum summaries and your typed context.")
            }
        }
    }

    private var reviewView: some View {
        Group {
            BackHeader(parent: "Lab", title: recorder.isRecording ? "Recording Event..." : "Review Event", actionTitle: "Clear", onBack: {
                recorder.stop()
                route = .home
            }, onAction: {
                clearDraft()
                route = .home
            })

            if recorder.isRecording {
                AppSection {
                    AppCard(padding: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recording in progress")
                                    .font(.headline)
                                    .foregroundStyle(TennitusStyle.warning)
                                Text("\(recorder.elapsedSeconds)s of 120s")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                stopAndAnalyse()
                            } label: {
                                Label("Stop", systemImage: "stop.circle.fill")
                            }
                            .buttonStyle(AppButtonStyle(variant: .danger))
                        }
                    }
                }
            }

            AppSection("What bothered you") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        FlowChipGrid(options: labelOptions, selected: $selectedLabels)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reaction intensity: \(Int(reactionIntensity))/10")
                                .font(.subheadline)
                            Slider(value: $reactionIntensity, in: 1...10, step: 1)
                        }

                        TextField("Describe the sound, e.g. brake squeal, fan whine, voice sibilance", text: $userDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                        TextField("Context, e.g. train, cafe, headphones, poor sleep", text: $backgroundDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            if let recordingResult, let latestAnalysis {
                AppSection("Waveform") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            WaveformSelectionView(
                                samples: recordingResult.samples,
                                selectedStart: selectedStartSeconds,
                                selectedEnd: selectedEndSeconds,
                                duration: recordingDurationSeconds
                            )
                            .frame(height: 150)

                            Text("\(formatTime(selectedStartSeconds)) - \(formatTime(selectedEndSeconds)) of \(formatTime(recordingDurationSeconds))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)

                            segmentSliders

                            HStack(spacing: 10) {
                                Button {
                                    toggleSelectionPlayback(url: latestRecordingURL)
                                } label: {
                                    Label(playbackPlayer.isPlaying ? "Stop" : "Play", systemImage: playbackPlayer.isPlaying ? "stop.circle" : "play.circle")
                                }
                                .buttonStyle(AppButtonStyle(variant: .secondary))

                                Button {
                                    reanalyseSelectedSegment()
                                } label: {
                                    Label("Analyse", systemImage: "scope")
                                }
                                .buttonStyle(AppButtonStyle(variant: .primary))
                            }
                        }
                    }
                }

                AppSection("Analysis") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            analysisMetricGrid(latestAnalysis)
                            BandEnergyBarsView(analysis: latestAnalysis)

                            Button {
                                reanalyseSelectedSegment()
                                prepareNotchFromCurrentAnalysis()
                                route = .spectrum
                            } label: {
                                Label("Open spectrum review", systemImage: "chart.xyaxis.line")
                            }
                            .buttonStyle(AppButtonStyle(variant: .accent))
                        }
                    }
                }
            } else if !recorder.isRecording {
                emptyLabState(
                    title: "No recording yet",
                    subtitle: "Start with Log Sound Event to capture audio before review.",
                    actionTitle: "Start recording",
                    systemImage: "mic.fill"
                ) {
                    route = .record
                }
            }
        }
    }

    private var spectrumView: some View {
        Group {
            BackHeader(parent: "Review", title: "Spectrum Review", actionTitle: nil, onBack: {
                route = .review
            }, onAction: nil)

            if let recordingResult, let latestAnalysis {
                let snapshotAnalysis = selectedSpectrumSnapshot?.analysis ?? latestAnalysis
                let displayedAnalysis = compareNotch ? (notchedAnalysis ?? snapshotAnalysis) : snapshotAnalysis

                AppSection("A/B waveform") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            WaveformSelectionView(
                                samples: recordingResult.samples,
                                selectedStart: selectedStartSeconds,
                                selectedEnd: selectedEndSeconds,
                                duration: recordingDurationSeconds,
                                comparisonSamples: compareNotch && !notchedSamples.isEmpty ? notchedSamples : nil,
                                highlightedStart: selectedSpectrumSnapshot?.startSeconds,
                                highlightedEnd: selectedSpectrumSnapshot.map { $0.startSeconds + $0.durationSeconds },
                                visibleStart: waveformVisibleRange.lowerBound,
                                visibleEnd: waveformVisibleRange.upperBound
                            )
                            .frame(height: 140)

                            HStack(spacing: 12) {
                                Text("Waveform zoom")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TennitusStyle.muted)
                                Slider(value: $waveformZoom, in: 1...8, step: 0.5)
                                Text("\(waveformZoom.formatted(.number.precision(.fractionLength(1))))x")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(TennitusStyle.muted)
                            }

                            Toggle("Compare notched preview", isOn: $compareNotch)
                                .disabled(notchedSamples.isEmpty)

                            HStack(spacing: 10) {
                                Button {
                                    toggleSelectionPlayback(url: latestRecordingURL)
                                } label: {
                                    Label("Original", systemImage: "play.circle")
                                }
                                .buttonStyle(AppButtonStyle(variant: .secondary))

                                Button {
                                    toggleSelectionPlayback(url: notchedURL)
                                } label: {
                                    Label("Notched", systemImage: "waveform.badge.minus")
                                }
                                .buttonStyle(AppButtonStyle(variant: .secondary))
                                .disabled(notchedURL == nil)
                            }
                        }
                    }
                }

                AppSection("Spectrum") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            if !spectrumSnapshots.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("STFT snapshot")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(selectedSpectrumLabel)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(TennitusStyle.muted)
                                    }
                                    Slider(value: spectrumSnapshotIndexBinding, in: 0...Double(max(0, spectrumSnapshots.count - 1)), step: 1)
                                        .accentColor(TennitusStyle.accent)
                                }
                            }

                            if !spectrumSnapshots.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Spectrogram")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text("0.5s frames")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(TennitusStyle.muted)
                                    }
                                    SpectrogramHeatmapView(snapshots: spectrumSnapshots, selectedSnapshotID: $selectedSpectrumSnapshotID)
                                    Text("Read left to right as time. Low frequencies are lower on the plot, high frequencies are higher. Warmer colours mean more energy in that band for the selected half-second frame.")
                                        .font(.caption)
                                        .foregroundStyle(TennitusStyle.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack(spacing: 10) {
                                        heatLegend("Low", color: Color(red: 0.07, green: 0.13, blue: 0.34))
                                        heatLegend("Mid", color: Color(red: 0.06, green: 0.45, blue: 0.48))
                                        heatLegend("High", color: Color(red: 0.93, green: 0.72, blue: 0.20))
                                        heatLegend("Peak", color: Color(red: 0.86, green: 0.18, blue: 0.12))
                                    }
                                }
                            }

                            SpectrumCurveView(
                                analysis: displayedAnalysis,
                                tinnitusHz: tonePlayer.frequencyHz,
                                bothersomeHz: bothersomeMarkerHz(for: displayedAnalysis),
                                notchHz: notchedSamples.isEmpty ? nil : notchHz
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Notch preview")
                                    Spacer()
                                    Text("\(Int(notchHz)) Hz")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                Slider(value: $notchHz, in: 125...12_000, step: 25)
                                    .accentColor(TennitusStyle.accent)
                            }

                            Button {
                                applyNotchPreview()
                            } label: {
                                Label("Apply local notch preview", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(AppButtonStyle(variant: .primary))

                            BandEnergyBarsView(analysis: displayedAnalysis)
                        }
                    }
                }

                AppSection("Next") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The notch preview is an A/B listening and visualisation tool. It is not an AirPods system EQ and should not be treated as therapy.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button {
                                recomputeLocalSuggestion(displayedAnalysis)
                                route = .ai
                            } label: {
                                Label("Suggest comfort session", systemImage: "sparkles")
                            }
                            .buttonStyle(AppButtonStyle(variant: .accent))
                        }
                    }
                }
            } else {
                emptyLabState(
                    title: "No spectrum yet",
                    subtitle: "Record and analyse a sound event first.",
                    actionTitle: "Record event",
                    systemImage: "mic.fill"
                ) {
                    route = .record
                }
            }
        }
    }

    private var aiView: some View {
        Group {
            BackHeader(parent: "Spectrum", title: "AI Suggestion", actionTitle: nil, onBack: {
                route = .spectrum
            }, onAction: nil)

            if let latestAnalysis {
                AppSection("Local suggestion") {
                    SuggestionCard(suggestion: localSuggestion)
                }

                AppSection("AI Comfort Session") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            Button {
                                runAIAnalysis(latestAnalysis)
                            } label: {
                                Label(isAnalysingWithAI ? "Analysing..." : "Analyse numeric summary", systemImage: isAnalysingWithAI ? "hourglass" : "sparkles")
                            }
                            .buttonStyle(AppButtonStyle(variant: .primary))
                            .disabled(isAnalysingWithAI)

                            if let aiError {
                                Text(aiError)
                                    .font(.footnote)
                                    .foregroundStyle(TennitusStyle.warning)
                            }

                            Text("Production builds securely call the AI through the backend proxy. The app sends only frequency/loudness numbers plus your typed description.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let aiSuggestion {
                    AppSection("Comfort Suggestion") {
                        SuggestionCard(suggestion: aiSuggestion)
                    }
                }

                AppSection {
                    Button {
                        saveEvent()
                    } label: {
                        Label("Save event and suggestion", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(AppButtonStyle(variant: .accent))

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }
            } else {
                emptyLabState(
                    title: "No analysis yet",
                    subtitle: "Run spectrum review before asking for a suggestion.",
                    actionTitle: "Record event",
                    systemImage: "mic.fill"
                ) {
                    route = .record
                }
            }
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 64)
    }

    private var segmentSliders: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(get: {
                    selectedStartSeconds
                }, set: { newValue in
                    selectedStartSeconds = min(max(0, newValue), max(0, selectedEndSeconds - 0.25))
                }), in: 0...max(0.25, recordingDurationSeconds), step: 0.1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("End")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(get: {
                    selectedEndSeconds
                }, set: { newValue in
                    selectedEndSeconds = max(min(recordingDurationSeconds, newValue), selectedStartSeconds + 0.25)
                }), in: 0...max(0.25, recordingDurationSeconds), step: 0.1)
            }
        }
    }

    private var toneSliderBinding: Binding<Double> {
        Binding(get: {
            let minValue = log10(matchLowHz)
            let maxValue = log10(matchHighHz)
            let clamped = max(matchLowHz, min(matchHighHz, tonePlayer.frequencyHz))
            return (log10(clamped) - minValue) / (maxValue - minValue)
        }, set: { value in
            let minValue = log10(matchLowHz)
            let maxValue = log10(matchHighHz)
            tonePlayer.frequencyHz = pow(10, minValue + max(0, min(1, value)) * (maxValue - minValue))
        })
    }

    private var lowerBandBinding: Binding<Double> {
        Binding(get: {
            matchLowHz
        }, set: { newValue in
            matchLowHz = min(max(125, newValue), matchHighHz - 125)
            tonePlayer.frequencyHz = max(matchLowHz, min(matchHighHz, tonePlayer.frequencyHz))
        })
    }

    private var upperBandBinding: Binding<Double> {
        Binding(get: {
            matchHighHz
        }, set: { newValue in
            matchHighHz = max(min(12_000, newValue), matchLowHz + 125)
            tonePlayer.frequencyHz = max(matchLowHz, min(matchHighHz, tonePlayer.frequencyHz))
        })
    }

    private var savedToneSubtitle: String {
        guard let savedHz = store.profile.savedToneFrequencyHz else {
            return "No saved match yet"
        }

        let waveform = store.profile.savedToneWaveform?.rawValue ?? ToneWaveform.sine.rawValue
        return "Last saved: \(formatHz(savedHz)) · \(waveform)"
    }

    private var selectedSpectrumSnapshot: SpectrumSnapshot? {
        guard let selectedSpectrumSnapshotID else { return spectrumSnapshots.first }
        return spectrumSnapshots.first { $0.id == selectedSpectrumSnapshotID } ?? spectrumSnapshots.first
    }

    private var selectedSpectrumLabel: String {
        guard let snapshot = selectedSpectrumSnapshot else { return "Full recording" }
        let start = snapshot.startSeconds.formatted(.number.precision(.fractionLength(1)))
        let end = (snapshot.startSeconds + snapshot.durationSeconds).formatted(.number.precision(.fractionLength(1)))
        return "\(start)-\(end)s"
    }

    private var spectrumSnapshotIndexBinding: Binding<Double> {
        Binding(get: {
            guard let selectedSpectrumSnapshotID, let index = spectrumSnapshots.firstIndex(where: { $0.id == selectedSpectrumSnapshotID }) else {
                return 0
            }
            return Double(index)
        }, set: { newValue in
            let index = max(0, min(spectrumSnapshots.count - 1, Int(newValue.rounded())))
            selectedSpectrumSnapshotID = spectrumSnapshots.indices.contains(index) ? spectrumSnapshots[index].id : nil
        })
    }

    private var waveformVisibleRange: ClosedRange<Double> {
        guard recordingDurationSeconds > 0, waveformZoom > 1, let snapshot = selectedSpectrumSnapshot else {
            return 0...max(0, recordingDurationSeconds)
        }

        let span = max(0.5, recordingDurationSeconds / waveformZoom)
        let center = snapshot.startSeconds + snapshot.durationSeconds / 2
        let lower = max(0, min(center - span / 2, recordingDurationSeconds - span))
        let upper = min(recordingDurationSeconds, lower + span)
        return lower...upper
    }

    private var levelProgress: Double {
        max(0, min(1, (recorder.loudnessDBFS + 60) / 60))
    }

    private func toolRow(icon: String, title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(TennitusStyle.graphite)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(TennitusStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(title), action)
    }

    private func recentEventRow(_ event: AudioEventLog) -> some View {
        HStack(spacing: 14) {
            MiniWaveView(color: TennitusStyle.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(TennitusStyle.graphite)
                Text("\(event.analysis.dominantBandLabel), matched \(Int(event.tinnitusMatchFrequencyHz)) Hz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(event.localSuggestion.title)
                    .font(.caption)
                    .foregroundStyle(TennitusStyle.primary)
                    .lineLimit(1)
            }
            Spacer()
            if let path = event.audioFilePath {
                Button {
                    playbackPlayer.play(url: URL(fileURLWithPath: path), range: event.selectedStartSeconds...event.selectedEndSeconds)
                } label: {
                    Image(systemName: "play.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TennitusStyle.primary)
            }
        }
        .padding(16)
    }

    private func heatLegend(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundStyle(TennitusStyle.muted)
        }
    }

    private func analysisMetricGrid(_ analysis: AudioAnalysisSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatBlock(label: "Dominant", value: analysis.dominantBandLabel, unit: nil)
            StatBlock(label: "Range", value: analysis.sensitiveRangeLabel, unit: nil)
            StatBlock(label: "Centroid", value: "\(Int(analysis.spectralCentroidHz))", unit: "Hz")
            StatBlock(label: "Peak", value: analysis.peakDBFS.formatted(.number.precision(.fractionLength(1))), unit: "dBFS")
        }
    }

    private func emptyLabState(title: String, subtitle: String, actionTitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        AppSection {
            AppCard(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(TennitusStyle.primary)
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(action: action) {
                        Label(actionTitle, systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(AppButtonStyle(variant: .primary))
                }
            }
        }
    }

    private func stopAndAnalyse() {
        let result = recorder.stopAndAnalyse()
        recordingResult = result
        latestAnalysis = result.analysis
        latestRecordingURL = result.audioFileURL
        recordingDurationSeconds = result.durationSeconds
        selectedStartSeconds = 0
        selectedEndSeconds = max(0, result.durationSeconds)
        spectrumSnapshots = SpectrumAnalyzer.stftSnapshots(samples: result.samples, sampleRate: result.sampleRate, windowSeconds: 0.5, hopSeconds: 0.5)
        selectedSpectrumSnapshotID = spectrumSnapshots.first?.id
        waveformZoom = 1
        selectedLabels = []
        reactionIntensity = 6
        prepareNotchFromCurrentAnalysis()
        recomputeLocalSuggestion(result.analysis)
        aiSuggestion = nil
        aiError = nil
        saveMessage = nil
    }

    private func reanalyseSelectedSegment() {
        guard let recordingResult, selectedEndSeconds > selectedStartSeconds else { return }
        let analysis = SpectrumAnalyzer.analyze(
            samples: recordingResult.samples,
            sampleRate: recordingResult.sampleRate,
            startSeconds: selectedStartSeconds,
            endSeconds: selectedEndSeconds
        )
        latestAnalysis = analysis
        prepareNotchFromCurrentAnalysis()
        recomputeLocalSuggestion(analysis)
        aiSuggestion = nil
        aiError = nil
        saveMessage = "Updated analysis for selected segment."
    }

    private func prepareNotchFromCurrentAnalysis() {
        if let latestAnalysis, latestAnalysis.sensitiveRangeLowHz > 0, latestAnalysis.sensitiveRangeHighHz > latestAnalysis.sensitiveRangeLowHz {
            notchHz = sqrt(latestAnalysis.sensitiveRangeLowHz * latestAnalysis.sensitiveRangeHighHz)
        } else {
            notchHz = max(125, min(12_000, tonePlayer.frequencyHz))
        }
        notchedSamples = []
        notchedURL = nil
        notchedAnalysis = nil
        compareNotch = false
    }

    private func applyNotchPreview() {
        guard let recordingResult else { return }
        let processed = NotchFilterProcessor.apply(samples: recordingResult.samples, sampleRate: recordingResult.sampleRate, frequencyHz: notchHz)
        notchedSamples = processed.samples
        notchedURL = processed.url
        notchedAnalysis = SpectrumAnalyzer.analyze(
            samples: processed.samples,
            sampleRate: recordingResult.sampleRate,
            startSeconds: selectedStartSeconds,
            endSeconds: selectedEndSeconds
        )
        compareNotch = true
    }

    private func recomputeLocalSuggestion(_ analysis: AudioAnalysisSummary) {
        let context = [
            userDescription,
            backgroundDescription,
            selectedLabels.sorted().joined(separator: ", "),
            "reaction \(Int(reactionIntensity))/10"
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        localSuggestion = SpectrumAnalyzer.localSuggestion(
            analysis: analysis,
            tinnitusMatchHz: tonePlayer.frequencyHz,
            description: context
        )
    }

    private func runAIAnalysis(_ analysis: AudioAnalysisSummary) {
        recomputeLocalSuggestion(analysis)
        isAnalysingWithAI = true
        aiError = nil

        Task {
            do {
                let triggerScore = TriggerWeightingEngine.calculate(store: store, analysis: analysis)
                let suggestion = try await store.comfortAdvisor.suggestComfortSession(
                    subtype: store.detectedSubtype,
                    analysis: analysis,
                    tinnitusMatchHz: tonePlayer.frequencyHz,
                    userDescription: userDescription,
                    backgroundDescription: "\(backgroundDescription) Tags: \(selectedLabels.sorted().joined(separator: ", ")). Reaction: \(Int(reactionIntensity))/10.",
                    triggerScore: triggerScore,
                    healthContext: store.appleHealthContext
                )
                await MainActor.run {
                    aiSuggestion = suggestion
                    saveAIResponse(suggestion, analysis: analysis)
                    isAnalysingWithAI = false
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                    isAnalysingWithAI = false
                }
            }
        }
    }

    private func saveEvent() {
        guard let analysis = latestAnalysis else { return }
        recomputeLocalSuggestion(analysis)

        let enrichedDescription = [
            userDescription,
            selectedLabels.isEmpty ? "" : "Tags: \(selectedLabels.sorted().joined(separator: ", "))",
            "Reaction intensity: \(Int(reactionIntensity))/10"
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        let event = AudioEventLog(
            audioFilePath: latestRecordingURL?.path,
            selectedStartSeconds: selectedStartSeconds,
            selectedEndSeconds: selectedEndSeconds,
            userDescription: enrichedDescription,
            backgroundDescription: backgroundDescription,
            tinnitusMatchFrequencyHz: tonePlayer.frequencyHz,
            analysis: analysis,
            localSuggestion: localSuggestion,
            aiSuggestion: aiSuggestion
        )
        store.save(event)
        saveMessage = "Saved event with \(analysis.dominantBandLabel) dominant band."
    }

    private func saveAIResponse(_ suggestion: ComfortSessionSuggestion, analysis: AudioAnalysisSummary) {
        let response = AIResponseLog(
            source: "AI Proxy",
            tinnitusMatchFrequencyHz: tonePlayer.frequencyHz,
            userDescription: userDescription,
            backgroundDescription: "\(backgroundDescription) Tags: \(selectedLabels.sorted().joined(separator: ", ")). Reaction: \(Int(reactionIntensity))/10.",
            analysis: analysis,
            suggestion: suggestion
        )
        store.save(response)
    }

    private func clearDraft(keepDescriptions: Bool = false) {
        recorder.stop()
        playbackPlayer.stop()
        recordingResult = nil
        latestAnalysis = nil
        latestRecordingURL = nil
        recordingDurationSeconds = 0
        selectedStartSeconds = 0
        selectedEndSeconds = 0
        spectrumSnapshots = []
        selectedSpectrumSnapshotID = nil
        waveformZoom = 1
        notchedSamples = []
        notchedURL = nil
        notchedAnalysis = nil
        compareNotch = false
        localSuggestion = .empty
        aiSuggestion = nil
        aiError = nil
        saveMessage = nil
        if !keepDescriptions {
            userDescription = ""
            backgroundDescription = ""
            selectedLabels = []
            reactionIntensity = 6
        }
    }

    private func toggleSelectionPlayback(url: URL?) {
        guard let url else { return }
        if playbackPlayer.isPlaying {
            playbackPlayer.stop()
        } else {
            playbackPlayer.play(url: url, range: selectedStartSeconds...selectedEndSeconds)
        }
    }

    private func adjustTone(by delta: Double) {
        tonePlayer.frequencyHz = max(matchLowHz, min(matchHighHz, tonePlayer.frequencyHz + delta))
    }

    private func setMatchBand(low: Double, high: Double) {
        matchLowHz = low
        matchHighHz = high
        tonePlayer.frequencyHz = max(low, min(high, tonePlayer.frequencyHz))
    }

    private func loadToneProfile() {
        tonePlayer.frequencyHz = store.profile.savedToneFrequencyHz ?? tonePlayer.frequencyHz
        tonePlayer.waveform = store.profile.savedToneWaveform ?? .sine
        matchLowHz = store.profile.toneMatchLowHz ?? 125
        matchHighHz = store.profile.toneMatchHighHz ?? 12_000
        if matchHighHz <= matchLowHz {
            matchLowHz = 125
            matchHighHz = 12_000
        }
        tonePlayer.frequencyHz = max(matchLowHz, min(matchHighHz, tonePlayer.frequencyHz))
    }

    private func saveToneMatchToProfile() {
        store.profile.savedToneFrequencyHz = tonePlayer.frequencyHz
        store.profile.savedToneWaveform = tonePlayer.waveform
        store.profile.toneMatchLowHz = matchLowHz
        store.profile.toneMatchHighHz = matchHighHz
        toneSaveMessage = "Saved \(formatHz(tonePlayer.frequencyHz)) \(tonePlayer.waveform.rawValue.lowercased()) match to profile."
    }

    private func bothersomeMarkerHz(for analysis: AudioAnalysisSummary) -> Double? {
        guard analysis.sensitiveRangeLowHz > 0, analysis.sensitiveRangeHighHz > analysis.sensitiveRangeLowHz else { return nil }
        return sqrt(analysis.sensitiveRangeLowHz * analysis.sensitiveRangeHighHz)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalTenths = Int((seconds * 10).rounded())
        return "\(totalTenths / 10).\(totalTenths % 10)s"
    }

    private func formatHz(_ hz: Double) -> String {
        hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz)) Hz"
    }
}

private struct FlowChipGrid: View {
    var options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                PillButton(title: option, active: selected.contains(option)) {
                    if selected.contains(option) {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                }
            }
        }
    }
}

private struct SuggestionCard: View {
    var suggestion: ComfortSessionSuggestion

    var body: some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.headline)
                            .foregroundStyle(TennitusStyle.graphite)
                        Text(suggestion.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(suggestion.confidence)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(TennitusStyle.primary.opacity(0.10), in: Capsule())
                        .foregroundStyle(TennitusStyle.primary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatBlock(label: "Target", value: suggestion.targetFrequencyRange, unit: nil)
                    StatBlock(label: "Duration", value: "\(suggestion.durationMinutes)", unit: "min")
                    StatBlock(label: "Sound", value: suggestion.suggestedSound, unit: nil)
                    if let suggestedFrequencyHz = suggestion.suggestedFrequencyHz {
                        StatBlock(label: "Tone", value: "\(Int(suggestedFrequencyHz))", unit: "Hz")
                    }
                }

                if !suggestion.rationale.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rationale")
                            .font(.subheadline.weight(.semibold))
                        ForEach(suggestion.rationale, id: \.self) { item in
                            Label(item, systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !suggestion.safetyNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Safety")
                            .font(.subheadline.weight(.semibold))
                        ForEach(suggestion.safetyNotes, id: \.self) { item in
                            Label(item, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.warning)
                        }
                    }
                }

                Text(suggestion.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BandEnergyBarsView: View {
    var analysis: AudioAnalysisSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Band energy", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(TennitusStyle.graphite)
                Spacer()
                Text(analysis.dominantBandLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TennitusStyle.primary)
            }

            ForEach(analysis.bandEnergies) { band in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(band.label)
                        Spacer()
                        Text("\(Int(band.relativeEnergy * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(TennitusStyle.background)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(band.label == analysis.dominantBandLabel ? TennitusStyle.primary : TennitusStyle.primary.opacity(0.35))
                                .frame(width: proxy.size.width * CGFloat(max(0, min(1, band.relativeEnergy))))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}
