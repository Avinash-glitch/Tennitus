import SwiftUI

struct WaveformSelectionView: View {
    var samples: [Float]
    var selectedStart: Double
    var selectedEnd: Double
    var duration: Double
    var comparisonSamples: [Float]?
    var highlightedStart: Double?
    var highlightedEnd: Double?
    var visibleStart: Double = 0
    var visibleEnd: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TennitusStyle.background)

                centerLine(size: size)
                    .stroke(TennitusStyle.graphite.opacity(0.08), lineWidth: 1)

                if duration > 0 {
                    selectionRect(size: size)
                        .fill(TennitusStyle.accent.opacity(0.14))
                    selectionBoundary(position: xPosition(for: selectedStart, width: size.width), height: size.height)
                        .fill(TennitusStyle.accent)
                    selectionBoundary(position: xPosition(for: selectedEnd, width: size.width), height: size.height)
                        .fill(TennitusStyle.accent)
                }

                if let highlightedStart, let highlightedEnd, duration > 0 {
                    timeRect(start: highlightedStart, end: highlightedEnd, size: size)
                        .fill(TennitusStyle.accent.opacity(0.20))
                    selectionBoundary(position: xPosition(for: highlightedStart, width: size.width), height: size.height)
                        .fill(TennitusStyle.accent)
                    selectionBoundary(position: xPosition(for: highlightedEnd, width: size.width), height: size.height)
                        .fill(TennitusStyle.accent)
                }

                if let comparisonSamples {
                    waveformPath(samples: comparisonSamples, size: size)
                        .stroke(TennitusStyle.accent.opacity(0.55), lineWidth: 1.2)
                }

                waveformPath(samples: samples, size: size)
                    .stroke(TennitusStyle.primary, lineWidth: 1.4)
            }
        }
    }

    private func centerLine(size: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        return path
    }

    private func waveformPath(samples: [Float], size: CGSize) -> Path {
        guard !samples.isEmpty, size.width > 0 else { return Path() }
        let visibleSamples = visibleSampleSlice(samples)
        let bucketCount = max(1, min(260, Int(size.width)))
        let step = max(1, visibleSamples.count / bucketCount)
        var path = Path()

        for xIndex in 0..<bucketCount {
            let start = xIndex * step
            let end = min(visibleSamples.count, start + step)
            guard start < end else { continue }

            let slice = visibleSamples[start..<end]
            let minValue = CGFloat(slice.min() ?? 0)
            let maxValue = CGFloat(slice.max() ?? 0)
            let x = CGFloat(xIndex)
            let y1 = size.height / 2 - maxValue * (size.height / 2 - 6)
            let y2 = size.height / 2 - minValue * (size.height / 2 - 6)
            path.move(to: CGPoint(x: x, y: y1))
            path.addLine(to: CGPoint(x: x, y: y2))
        }

        return path
    }

    private func selectionRect(size: CGSize) -> Path {
        timeRect(start: selectedStart, end: selectedEnd, size: size)
    }

    private func timeRect(start: Double, end: Double, size: CGSize) -> Path {
        let x1 = xPosition(for: start, width: size.width)
        let x2 = xPosition(for: end, width: size.width)
        var path = Path()
        path.addRect(CGRect(x: min(x1, x2), y: 0, width: abs(x2 - x1), height: size.height))
        return path
    }

    private func selectionBoundary(position: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: position - 1, y: 0, width: 2, height: height), cornerSize: CGSize(width: 1, height: 1))
        return path
    }

    private func xPosition(for seconds: Double, width: CGFloat) -> CGFloat {
        let end = visibleEnd ?? duration
        let span = max(0.001, end - visibleStart)
        return width * CGFloat(max(0, min(1, (seconds - visibleStart) / span)))
    }

    private func visibleSampleSlice(_ samples: [Float]) -> ArraySlice<Float> {
        let end = visibleEnd ?? duration
        guard duration > 0, end > visibleStart else { return samples[...] }
        let lower = max(0, min(samples.count, Int((visibleStart / duration) * Double(samples.count))))
        let upper = max(lower + 1, min(samples.count, Int((end / duration) * Double(samples.count))))
        return samples[lower..<upper]
    }
}

struct SpectrogramHeatmapView: View {
    var snapshots: [SpectrumSnapshot]
    @Binding var selectedSnapshotID: UUID?
    @State private var selectedCell: SpectrogramCellSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TennitusStyle.background)

                    Canvas { context, _ in
                        drawHeatmap(context: context, size: size)
                    }

                    if let selectedIndex {
                        Rectangle()
                            .fill(TennitusStyle.accent)
                            .frame(width: 2, height: size.height)
                            .offset(x: xForIndex(selectedIndex, width: size.width), y: 0)
                    }

                    if let selectedCell {
                        selectionOverlay(selection: selectedCell, size: size)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            selectCell(at: value.location, size: size)
                        }
                )
            }
            .frame(height: 150)

            HStack {
                Text(selectedCell?.readout ?? "Tap the spectrogram for time, frequency and energy")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TennitusStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                Text("x time · y frequency")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TennitusStyle.muted)
            }
        }
    }

    private var selectedIndex: Int? {
        guard let selectedSnapshotID else { return nil }
        return snapshots.firstIndex { $0.id == selectedSnapshotID }
    }

    private func drawHeatmap(context: GraphicsContext, size: CGSize) {
        guard !snapshots.isEmpty else { return }

        let columnWidth = max(2, size.width / CGFloat(snapshots.count))
        for (index, snapshot) in snapshots.enumerated() {
            let x = min(size.width - columnWidth, CGFloat(index) * columnWidth)
            let points = decimated(points: snapshot.analysis.spectrumPoints, maxCount: 52)
            for point in points {
                let rowHeight = max(2, size.height / CGFloat(max(24, points.count)))
                let y = min(size.height - rowHeight, yForFrequency(point.frequencyHz, height: size.height))
                let rect = CGRect(x: x, y: y, width: columnWidth + 0.5, height: rowHeight + 0.5)
                context.fill(Path(rect), with: .color(heatColor(point.normalizedMagnitude)))
            }
        }
    }

    private func selectionOverlay(selection: SpectrogramCellSelection, size: CGSize) -> some View {
        let x = xForIndex(selection.snapshotIndex, width: size.width)
        let y = yForFrequency(selection.point.frequencyHz, height: size.height)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: size.width, height: 1)
                .offset(x: 0, y: y)
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(TennitusStyle.graphite.opacity(0.2), lineWidth: 1))
                .offset(x: min(size.width - 10, max(1, x - 4.5)), y: min(size.height - 10, max(1, y - 4.5)))
            Text(selection.shortReadout)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .foregroundStyle(.white)
                .background(TennitusStyle.graphite.opacity(0.86), in: Capsule())
                .offset(x: min(size.width - 116, max(6, x + 8)), y: min(size.height - 24, max(6, y - 26)))
        }
    }

    private func selectCell(at location: CGPoint, size: CGSize) {
        guard !snapshots.isEmpty, size.width > 0, size.height > 0 else { return }
        let snapshotIndex = nearestSnapshotIndex(x: location.x, width: size.width)
        let snapshot = snapshots[snapshotIndex]
        let targetHz = frequencyForY(location.y, height: size.height)
        let point = nearestSpectrumPoint(in: snapshot, targetHz: targetHz)
        selectedSnapshotID = snapshot.id
        selectedCell = SpectrogramCellSelection(snapshotIndex: snapshotIndex, snapshot: snapshot, point: point)
    }

    private func nearestSnapshotIndex(x: CGFloat, width: CGFloat) -> Int {
        guard snapshots.count > 1 else { return 0 }
        let ratio = max(0, min(1, x / max(1, width)))
        return max(0, min(snapshots.count - 1, Int((ratio * CGFloat(snapshots.count - 1)).rounded())))
    }

    private func nearestSpectrumPoint(in snapshot: SpectrumSnapshot, targetHz: Double) -> FrequencySpectrumPoint {
        if let point = snapshot.analysis.spectrumPoints.min(by: { abs($0.frequencyHz - targetHz) < abs($1.frequencyHz - targetHz) }) {
            return point
        }

        if let band = snapshot.analysis.bandEnergies.min(by: {
            abs(sqrt($0.lowHz * $0.highHz) - targetHz) < abs(sqrt($1.lowHz * $1.highHz) - targetHz)
        }) {
            return FrequencySpectrumPoint(
                frequencyHz: sqrt(band.lowHz * band.highHz),
                magnitudeDB: band.energyDBFS,
                normalizedMagnitude: band.relativeEnergy
            )
        }

        return FrequencySpectrumPoint(frequencyHz: targetHz, magnitudeDB: -120, normalizedMagnitude: 0)
    }

    private func xForIndex(_ index: Int, width: CGFloat) -> CGFloat {
        guard snapshots.count > 1 else { return width / 2 }
        return CGFloat(index) * width / CGFloat(max(1, snapshots.count - 1))
    }

    private func yForFrequency(_ hz: Double, height: CGFloat) -> CGFloat {
        let minHz = log10(60.0)
        let maxHz = log10(16_000.0)
        let clamped = max(60, min(16_000, hz))
        let ratio = (log10(clamped) - minHz) / (maxHz - minHz)
        return height - height * CGFloat(ratio)
    }

    private func frequencyForY(_ y: CGFloat, height: CGFloat) -> Double {
        let minHz = log10(60.0)
        let maxHz = log10(16_000.0)
        let ratio = Double(max(0, min(1, 1 - y / max(1, height))))
        return pow(10, minHz + ratio * (maxHz - minHz))
    }

    private func heatColor(_ value: Double) -> Color {
        let clamped = max(0, min(1, value))
        switch clamped {
        case 0..<0.25:
            return Color(red: 0.07, green: 0.13, blue: 0.34).opacity(0.75)
        case 0.25..<0.5:
            return Color(red: 0.06, green: 0.45, blue: 0.48).opacity(0.80)
        case 0.5..<0.75:
            return Color(red: 0.93, green: 0.72, blue: 0.20).opacity(0.86)
        default:
            return Color(red: 0.86, green: 0.18, blue: 0.12).opacity(0.92)
        }
    }

    private func decimated(points: [FrequencySpectrumPoint], maxCount: Int) -> [FrequencySpectrumPoint] {
        guard points.count > maxCount, maxCount > 0 else { return points }
        let step = max(1, points.count / maxCount)
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: step) ? point : nil
        }
    }

}

private struct SpectrogramCellSelection {
    var snapshotIndex: Int
    var snapshot: SpectrumSnapshot
    var point: FrequencySpectrumPoint

    var readout: String {
        "\(timeRange) · \(frequencyLabel) · \(Int(point.magnitudeDB.rounded())) dB · \(Int((point.normalizedMagnitude * 100).rounded()))% energy"
    }

    var shortReadout: String {
        "\(frequencyLabel) \(Int(point.magnitudeDB.rounded()))dB"
    }

    private var timeRange: String {
        let start = snapshot.startSeconds.formatted(.number.precision(.fractionLength(1)))
        let end = (snapshot.startSeconds + snapshot.durationSeconds).formatted(.number.precision(.fractionLength(1)))
        return "\(start)-\(end)s"
    }

    private var frequencyLabel: String {
        point.frequencyHz >= 1_000
            ? "\(((point.frequencyHz / 1_000) * 10).rounded() / 10) kHz"
            : "\(Int(point.frequencyHz.rounded())) Hz"
    }
}

struct SpectrumCurveView: View {
    var analysis: AudioAnalysisSummary
    var tinnitusHz: Double?
    var bothersomeHz: Double?
    var notchHz: Double?
    @State private var selectedPoint: FrequencySpectrumPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TennitusStyle.background)

                    grid(size: size)
                        .stroke(TennitusStyle.graphite.opacity(0.07), lineWidth: 1)

                    areaPath(size: size)
                        .fill(TennitusStyle.primary.opacity(0.18))

                    curvePath(size: size)
                        .stroke(TennitusStyle.primary, lineWidth: 2)

                    if let tinnitusHz {
                        marker(hz: tinnitusHz, size: size, color: TennitusStyle.primary, label: "tinnitus")
                    }
                    if let bothersomeHz {
                        marker(hz: bothersomeHz, size: size, color: TennitusStyle.warning, label: "bother")
                    }
                    if let notchHz {
                        marker(hz: notchHz, size: size, color: TennitusStyle.accent, label: "notch")
                    }

                    if let selectedPoint {
                        selectedPointOverlay(point: selectedPoint, size: size)
                    }

                    axisLabels(size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            selectedPoint = nearestPoint(atX: value.location.x, width: size.width)
                        }
                )
            }
            .frame(height: 210)

            HStack(spacing: 14) {
                legend("Tinnitus", color: TennitusStyle.primary)
                legend("Bothersome", color: TennitusStyle.warning)
                legend("Notch", color: TennitusStyle.accent)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(selectedPoint.map { readoutText(for: $0) } ?? "Tap the spectrum line for frequency and level")
                .font(.caption.monospacedDigit())
                .foregroundStyle(TennitusStyle.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func grid(size: CGSize) -> Path {
        var path = Path()
        for hz in [125.0, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000] {
            let x = xPosition(hz: hz, width: size.width)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height - 30))
        }
        for row in 0...4 {
            let y = CGFloat(row) * (size.height - 30) / 4
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        return path
    }

    private func curvePath(size: CGSize) -> Path {
        var path = Path()
        for (index, point) in points(size: size).enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func areaPath(size: CGSize) -> Path {
        let plottedPoints = points(size: size)
        guard !plottedPoints.isEmpty else { return Path() }

        var path = Path()
        for (index, point) in plottedPoints.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height - 30))
        path.addLine(to: CGPoint(x: 0, y: size.height - 30))
        path.closeSubpath()
        return path
    }

    private func points(size: CGSize) -> [CGPoint] {
        if !analysis.spectrumPoints.isEmpty {
            return analysis.spectrumPoints.map { point in
                let x = xPosition(hz: point.frequencyHz, width: size.width)
                let y = (size.height - 30) - CGFloat(point.normalizedMagnitude) * (size.height - 40)
                return CGPoint(x: x, y: y)
            }
        }

        return analysis.bandEnergies.map { band in
            let hz = sqrt(band.lowHz * band.highHz)
            let x = xPosition(hz: hz, width: size.width)
            let y = (size.height - 30) - CGFloat(band.relativeEnergy) * (size.height - 40)
            return CGPoint(x: x, y: y)
        }
    }

    private func axisLabels(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([125.0, 500, 1_000, 2_000, 4_000, 8_000, 16_000], id: \.self) { hz in
                Text(axisFrequencyLabel(hz))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TennitusStyle.muted)
                    .position(x: xPosition(hz: hz, width: size.width), y: size.height - 12)
            }

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { normalized in
                Text(dbLabel(for: normalized))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TennitusStyle.muted)
                    .position(x: 18, y: (size.height - 30) - CGFloat(normalized) * (size.height - 40))
            }

            Text("dB")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(TennitusStyle.muted)
                .position(x: 16, y: 9)
            Text("Frequency")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(TennitusStyle.muted)
                .position(x: size.width - 34, y: size.height - 12)
        }
    }

    private func marker(hz: Double, size: CGSize, color: Color, label: String) -> some View {
        let x = xPosition(hz: hz, width: size.width)
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(color, in: Capsule())
                .foregroundStyle(.white)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: size.height - 32)
        }
        .position(x: min(size.width - 22, max(22, x + 8)), y: (size.height - 14) / 2)
    }

    private func selectedPointOverlay(point: FrequencySpectrumPoint, size: CGSize) -> some View {
        let x = xPosition(hz: point.frequencyHz, width: size.width)
        let y = (size.height - 30) - CGFloat(point.normalizedMagnitude) * (size.height - 40)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(TennitusStyle.graphite.opacity(0.35))
                .frame(width: 1, height: size.height - 30)
                .offset(x: x, y: 0)
            Rectangle()
                .fill(TennitusStyle.graphite.opacity(0.18))
                .frame(width: size.width, height: 1)
                .offset(x: 0, y: y)
            Circle()
                .fill(TennitusStyle.accent)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .offset(x: min(size.width - 10, max(1, x - 4.5)), y: min(size.height - 40, max(1, y - 4.5)))
            Text(readoutText(for: point))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .foregroundStyle(.white)
                .background(TennitusStyle.graphite.opacity(0.86), in: Capsule())
                .offset(x: min(size.width - 120, max(6, x + 8)), y: min(size.height - 56, max(6, y - 28)))
        }
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    private func xPosition(hz: Double, width: CGFloat) -> CGFloat {
        let minHz = log10(60.0)
        let maxHz = log10(16_000.0)
        let clamped = max(60, min(16_000, hz))
        return width * CGFloat((log10(clamped) - minHz) / (maxHz - minHz))
    }

    private func nearestPoint(atX x: CGFloat, width: CGFloat) -> FrequencySpectrumPoint? {
        let plotPoints = selectablePoints()
        guard !plotPoints.isEmpty else { return nil }
        return plotPoints.min {
            abs(xPosition(hz: $0.frequencyHz, width: width) - x) < abs(xPosition(hz: $1.frequencyHz, width: width) - x)
        }
    }

    private func selectablePoints() -> [FrequencySpectrumPoint] {
        if !analysis.spectrumPoints.isEmpty {
            return analysis.spectrumPoints
        }

        return analysis.bandEnergies.map { band in
            FrequencySpectrumPoint(
                frequencyHz: sqrt(band.lowHz * band.highHz),
                magnitudeDB: band.energyDBFS,
                normalizedMagnitude: band.relativeEnergy
            )
        }
    }

    private func readoutText(for point: FrequencySpectrumPoint) -> String {
        let frequency = point.frequencyHz >= 1_000
            ? "\(((point.frequencyHz / 1_000) * 10).rounded() / 10) kHz"
            : "\(Int(point.frequencyHz.rounded())) Hz"
        return "\(frequency) · \(Int(point.magnitudeDB.rounded())) dB · \(Int((point.normalizedMagnitude * 100).rounded()))% energy"
    }

    private func axisFrequencyLabel(_ hz: Double) -> String {
        hz >= 1_000 ? "\(Int(hz / 1_000))k" : "\(Int(hz))"
    }

    private func dbLabel(for normalized: Double) -> String {
        guard !analysis.spectrumPoints.isEmpty else {
            return "\(Int(normalized * 100))%"
        }
        let minDB = analysis.spectrumPoints.map(\.magnitudeDB).min() ?? -120
        let maxDB = analysis.spectrumPoints.map(\.magnitudeDB).max() ?? -20
        let db = minDB + normalized * max(1, maxDB - minDB)
        return "\(Int(db.rounded()))"
    }
}
