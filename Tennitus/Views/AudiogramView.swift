import SwiftUI

struct AudiogramView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var healthWriter = AppleHealthAudiogramWriter()
    @StateObject private var tonePlayer = AudiogramTonePlayer()

    @State private var points = AudiogramEngine.makeDefaultPoints()
    @State private var headphoneModel = "AirPods / headphones"
    @State private var calibrationStatus = "Uncalibrated screening estimate"
    @State private var selectedEar: AudiogramEar = .left
    @State private var testFrequencyHz = 1_000.0
    @State private var testLevelDBHL = 30.0
    @State private var generatedPDFURL: URL?
    @State private var statusMessage: String?
    @State private var isSavingToHealth = false

    private var result: AudiogramScreeningResult {
        AudiogramEngine.result(points: points, headphoneModel: headphoneModel, calibrationStatus: calibrationStatus)
    }

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "HEARING PROFILE",
                title: "Indicative Audiogram",
                subtitle: "Enter threshold estimates per ear, review ASHA-style screening tiers, export a PDF, and save threshold points to Apple Health."
            )

            setupSection
            chartSection
            guidedToneTestSection
            thresholdEntrySection
            summarySection
            exportSection

            AppSection {
                SafetyNote(text: "This is a screening workflow, not a calibrated clinical hearing test. Only save to Apple Health if you understand the result is indicative.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !store.latestAudiogram.points.isEmpty {
                points = store.latestAudiogram.points
                headphoneModel = store.latestAudiogram.headphoneModel
                calibrationStatus = store.latestAudiogram.calibrationStatus
            }
        }
        .onDisappear {
            tonePlayer.stop()
        }
    }

    private var setupSection: some View {
        AppSection("Setup") {
            AppCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Headphone model", text: $headphoneModel)
                        .textFieldStyle(.roundedBorder)
                    TextField("Calibration status", text: $calibrationStatus)
                        .textFieldStyle(.roundedBorder)
                    Picker("Ear", selection: $selectedEar) {
                        ForEach(AudiogramEar.allCases) { ear in
                            Text(ear.rawValue).tag(ear)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var chartSection: some View {
        AppSection("Audiogram preview") {
            AppCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    AudiogramGridView(points: points)
                        .frame(height: 280)

                    HStack(spacing: 14) {
                        legend("Right ear O", color: TennitusStyle.primary)
                        legend("Left ear X", color: TennitusStyle.accent)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Standard audiograms place lower dB HL near the top. These values depend on your device, headphones, environment, and calibration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var guidedToneTestSection: some View {
        AppSection("Guided tone test") {
            AppCard(padding: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(selectedEar.rawValue) ear")
                                .font(.headline)
                                .foregroundStyle(TennitusStyle.graphite)
                            Text("\(label(for: testFrequencyHz)) pulsed sine")
                                .font(.subheadline)
                                .foregroundStyle(TennitusStyle.muted)
                        }
                        Spacer()
                        Text("\(Int(testLevelDBHL)) dB HL")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(TennitusStyle.primary)
                    }

                    Picker("Ear", selection: $selectedEar) {
                        ForEach(AudiogramEar.allCases) { ear in
                            Text(ear.rawValue).tag(ear)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedEar) { _, _ in
                        restartToneIfNeeded()
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(AudiogramEngine.standardFrequencies, id: \.self) { frequency in
                            Button {
                                testFrequencyHz = frequency
                                restartToneIfNeeded()
                            } label: {
                                Text(label(for: frequency))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(testFrequencyHz == frequency ? TennitusStyle.primary : TennitusStyle.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .foregroundStyle(testFrequencyHz == frequency ? .white : TennitusStyle.graphite)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Presentation level")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("Current saved: \(Int(savedThreshold(for: selectedEar, frequency: testFrequencyHz))) dB HL")
                                .font(.caption)
                                .foregroundStyle(TennitusStyle.muted)
                        }

                        Slider(value: Binding(get: {
                            testLevelDBHL
                        }, set: { newValue in
                            testLevelDBHL = newValue
                            restartToneIfNeeded()
                        }), in: -10...100, step: 5)
                    }

                    HStack(spacing: 10) {
                        Button {
                            tonePlayer.isPlaying ? tonePlayer.stop() : startTestTone()
                        } label: {
                            Label(tonePlayer.isPlaying ? "Stop" : "Play tone", systemImage: tonePlayer.isPlaying ? "stop.fill" : "play.fill")
                        }
                        .buttonStyle(AppButtonStyle(variant: tonePlayer.isPlaying ? .danger : .primary))

                        Button {
                            saveCurrentThreshold()
                        } label: {
                            Label("Set threshold", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))
                    }

                    HStack(spacing: 10) {
                        Button {
                            adjustTestLevel(by: -10)
                        } label: {
                            Label("Heard: -10", systemImage: "minus")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))

                        Button {
                            adjustTestLevel(by: 5)
                        } label: {
                            Label("Not heard: +5", systemImage: "plus")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))
                    }

                    Toggle("Pulsed tone", isOn: $tonePlayer.isPulsed)
                        .font(.subheadline.weight(.medium))
                        .tint(TennitusStyle.primary)

                    Text("Set phone volume to a comfortable fixed level, use the same headphones, sit in a quiet room, and save the lowest level you can reliably hear. This is not calibrated like Apple’s AirPods Pro Hearing Test or a clinic audiogram.")
                        .font(.footnote)
                        .foregroundStyle(TennitusStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var thresholdEntrySection: some View {
        AppSection("\(selectedEar.rawValue) thresholds") {
            AppCard {
                ForEach(Array(AudiogramEngine.standardFrequencies.enumerated()), id: \.element) { index, frequency in
                    thresholdRow(frequency: frequency, ear: selectedEar)
                        .padding(16)
                    if index < AudiogramEngine.standardFrequencies.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        AppSection("ASHA-style tiers") {
            VStack(spacing: 12) {
                summaryCard("Left ear", result.leftSummary, tint: TennitusStyle.accent)
                summaryCard("Right ear", result.rightSummary, tint: TennitusStyle.primary)
            }
        }
    }

    private var exportSection: some View {
        AppSection("Export") {
            AppCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        let generated = result
                        store.save(generated)
                        do {
                            generatedPDFURL = try AudiogramReportRenderer.generate(result: generated)
                            statusMessage = "Saved screening result and generated PDF."
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    } label: {
                        Label("Generate Audiogram PDF", systemImage: "doc.richtext")
                    }
                    .buttonStyle(AppButtonStyle(variant: .primary))

                    if let generatedPDFURL {
                        ShareLink(item: generatedPDFURL) {
                            Label("Share Audiogram PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))
                    }

                    Button {
                        saveToAppleHealth()
                    } label: {
                        Label(isSavingToHealth ? "Saving..." : "Save to Apple Health", systemImage: "heart.text.square")
                    }
                    .buttonStyle(AppButtonStyle(variant: .secondary))
                    .disabled(isSavingToHealth)

                    Text(healthWriter.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func thresholdRow(frequency: Double, ear: AudiogramEar) -> some View {
        let index = points.firstIndex { $0.ear == ear && Int($0.frequencyHz) == Int(frequency) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label(for: frequency))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TennitusStyle.graphite)
                Spacer()
                Text("\(Int(index.map { points[$0].thresholdDBHL } ?? 0)) dB HL")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(ear == .left ? TennitusStyle.accent : TennitusStyle.primary)
            }
            if let index {
                Slider(value: Binding(get: {
                    points[index].thresholdDBHL
                }, set: { newValue in
                    points[index].thresholdDBHL = newValue
                }), in: -10...100, step: 5)
            }
        }
    }

    private func summaryCard(_ title: String, _ summary: AudiogramEarSummary, tint: Color) -> some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(TennitusStyle.graphite)
                    Spacer()
                    Text(summary.pta4Tier.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(tint.opacity(0.10), in: Capsule())
                        .foregroundStyle(tint)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatBlock(label: "PTA3", value: "\(format(summary.pta3DBHL))", unit: "dB HL")
                    StatBlock(label: "PTA4", value: "\(format(summary.pta4DBHL))", unit: "dB HL")
                    StatBlock(label: "High freq", value: "\(format(summary.highFrequencyAverageDBHL))", unit: "dB HL")
                    StatBlock(label: "Worst tier", value: summary.worstFrequencyTier.rawValue, unit: nil)
                }
            }
        }
    }

    private func saveToAppleHealth() {
        isSavingToHealth = true
        statusMessage = nil
        let generated = result
        store.save(generated)

        Task {
            do {
                try await healthWriter.requestAuthorization()
                try await healthWriter.save(result: generated)
                await MainActor.run {
                    isSavingToHealth = false
                    statusMessage = "Saved to Apple Health."
                }
            } catch {
                await MainActor.run {
                    isSavingToHealth = false
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func startTestTone() {
        tonePlayer.play(frequencyHz: testFrequencyHz, levelDBHL: testLevelDBHL, ear: selectedEar)
    }

    private func restartToneIfNeeded() {
        guard tonePlayer.isPlaying else { return }
        startTestTone()
    }

    private func adjustTestLevel(by delta: Double) {
        testLevelDBHL = min(100, max(-10, testLevelDBHL + delta))
        restartToneIfNeeded()
    }

    private func saveCurrentThreshold() {
        if let index = points.firstIndex(where: { $0.ear == selectedEar && Int($0.frequencyHz) == Int(testFrequencyHz) }) {
            points[index].thresholdDBHL = testLevelDBHL
        }
        calibrationStatus = "Uncalibrated guided tone screening"
        store.save(result)
        statusMessage = "Saved \(selectedEar.rawValue.lowercased()) \(label(for: testFrequencyHz)) at \(Int(testLevelDBHL)) dB HL."
        advanceTestFrequency()
    }

    private func advanceTestFrequency() {
        guard let index = AudiogramEngine.standardFrequencies.firstIndex(of: testFrequencyHz) else { return }
        let nextIndex = AudiogramEngine.standardFrequencies.index(after: index)
        if nextIndex < AudiogramEngine.standardFrequencies.endIndex {
            testFrequencyHz = AudiogramEngine.standardFrequencies[nextIndex]
        } else if selectedEar == .left {
            selectedEar = .right
            testFrequencyHz = AudiogramEngine.standardFrequencies[0]
        }
        testLevelDBHL = savedThreshold(for: selectedEar, frequency: testFrequencyHz)
        restartToneIfNeeded()
    }

    private func savedThreshold(for ear: AudiogramEar, frequency: Double) -> Double {
        points.first { $0.ear == ear && Int($0.frequencyHz) == Int(frequency) }?.thresholdDBHL ?? 15
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    private func label(for frequency: Double) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000)) kHz" : "\(Int(frequency)) Hz"
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}

private struct AudiogramGridView: View {
    var points: [AudiogramThresholdPoint]

    private let yTicks = [-10, 0, 20, 40, 60, 80, 100, 120]

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(x: 38, y: 14, width: max(1, proxy.size.width - 52), height: max(1, proxy.size.height - 44))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TennitusStyle.background)

                gridPath(plot: plot)
                    .stroke(TennitusStyle.graphite.opacity(0.10), lineWidth: 1)

                linePath(for: .right, plot: plot)
                    .stroke(TennitusStyle.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                linePath(for: .left, plot: plot)
                    .stroke(TennitusStyle.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4]))

                ForEach(points) { point in
                    Text(point.ear == .right ? "O" : "X")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(point.ear == .right ? TennitusStyle.primary : TennitusStyle.accent)
                        .position(position(for: point, plot: plot))
                }

                ForEach(AudiogramEngine.standardFrequencies, id: \.self) { frequency in
                    Text(axisLabel(for: frequency))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: xPosition(frequencyHz: frequency, plot: plot), y: plot.maxY + 16)
                }

                ForEach(yTicks, id: \.self) { tick in
                    Text("\(tick)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: 18, y: yPosition(dbHL: Double(tick), plot: plot))
                }

                Text("dB HL")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .position(x: 20, y: 8)
            }
        }
    }

    private func gridPath(plot: CGRect) -> Path {
        var path = Path()
        for frequency in AudiogramEngine.standardFrequencies {
            let x = xPosition(frequencyHz: frequency, plot: plot)
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        for tick in yTicks {
            let y = yPosition(dbHL: Double(tick), plot: plot)
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        return path
    }

    private func linePath(for ear: AudiogramEar, plot: CGRect) -> Path {
        let earPoints = points.filter { $0.ear == ear }.sorted { $0.frequencyHz < $1.frequencyHz }
        var path = Path()
        for (index, point) in earPoints.enumerated() {
            let location = position(for: point, plot: plot)
            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }
        return path
    }

    private func position(for point: AudiogramThresholdPoint, plot: CGRect) -> CGPoint {
        CGPoint(
            x: xPosition(frequencyHz: point.frequencyHz, plot: plot),
            y: yPosition(dbHL: point.thresholdDBHL, plot: plot)
        )
    }

    private func xPosition(frequencyHz: Double, plot: CGRect) -> CGFloat {
        let minValue = log10(250.0)
        let maxValue = log10(8_000.0)
        let clamped = max(250, min(8_000, frequencyHz))
        let ratio = (log10(clamped) - minValue) / (maxValue - minValue)
        return plot.minX + plot.width * CGFloat(ratio)
    }

    private func yPosition(dbHL: Double, plot: CGRect) -> CGFloat {
        let clamped = max(-10, min(120, dbHL))
        let ratio = (clamped + 10) / 130
        return plot.minY + plot.height * CGFloat(ratio)
    }

    private func axisLabel(for frequency: Double) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}
