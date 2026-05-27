import SwiftUI

struct AppleHealthHistoryView: View {
    var dataPoints: [AppleHealthDataPoint]

    @State private var selectedFilter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case sleep = "Sleep"
        case hearing = "Hearing"
        var id: String { rawValue }
    }

    private var filteredPoints: [AppleHealthDataPoint] {
        let sorted = dataPoints.sorted { $0.startDate > $1.startDate }
        switch selectedFilter {
        case .all:
            return sorted
        case .sleep:
            return sorted.filter { $0.kind == .sleepSegment }
        case .hearing:
            return sorted.filter { $0.kind == .audiogramLeft || $0.kind == .audiogramRight }
        }
    }

    var body: some View {
        AppScreen {
            VStack(spacing: 20) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                if filteredPoints.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 48))
                            .foregroundStyle(TennitusStyle.muted)
                        Text("No data available.")
                            .font(.headline)
                        Text("Sync Apple Health to see detailed points.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPoints) { point in
                            AppleHealthDataPointRow(point: point)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("All Health Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppleHealthDataPointRow: View {
    var point: AppleHealthDataPoint

    var body: some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TennitusStyle.graphite)
                    Spacer()
                    Text("\(formattedValue) \(point.unit)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(TennitusStyle.primary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(timestampLabel)
                        .font(.caption)
                        .foregroundStyle(TennitusStyle.muted)
                    Spacer()
                    if !metadataSummary.isEmpty {
                        Text(metadataSummary)
                            .font(.caption)
                            .foregroundStyle(TennitusStyle.muted)
                    }
                }

                if let source = point.sourceName {
                    Text("Source: \(source)")
                        .font(.caption2)
                        .foregroundStyle(TennitusStyle.muted.opacity(0.8))
                }
            }
        }
    }

    private var title: String {
        switch point.kind {
        case .sleepSegment: return "Sleep Segment"
        case .audiogramLeft: return "Audiogram (Left)"
        case .audiogramRight: return "Audiogram (Right)"
        }
    }

    private var formattedValue: String {
        point.value.formatted(.number.precision(.fractionLength(1)))
    }

    private var timestampLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: point.startDate)
    }

    private var metadataSummary: String {
        switch point.kind {
        case .sleepSegment:
            return point.metadata["Stage"] ?? ""
        case .audiogramLeft, .audiogramRight:
            return point.metadata["Frequency"] ?? ""
        }
    }
}
