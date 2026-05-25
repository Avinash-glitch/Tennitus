import SwiftUI

struct HealthSyncCard: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var healthReader = AppleHealthContextReader()
    @State private var message: String?
    @State private var isSyncing = false

    var body: some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.title3)
                        .foregroundStyle(TennitusStyle.primary)
                        .frame(width: 42, height: 42)
                        .background(TennitusStyle.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Health context")
                            .font(.headline)
                            .foregroundStyle(TennitusStyle.graphite)
                        Text("Sync sleep and hearing-test data for trend scoring.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    sync()
                } label: {
                    Label(isSyncing ? "Syncing..." : "Sync sleep and hearing", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(AppButtonStyle(variant: .secondary))
                .disabled(isSyncing)

                if let sleep = store.appleHealthContext.sleep {
                    contextRow(
                        icon: "bed.double",
                        text: "Sleep latest \(sleep.latestNightAsleepHours.formatted(.number.precision(.fractionLength(1))))h, 14-day avg \(sleep.averageAsleepHours.formatted(.number.precision(.fractionLength(1))))h"
                    )
                }

                if let hearing = store.appleHealthContext.hearing {
                    contextRow(
                        icon: "ear",
                        text: "Audiogram L \(dbLabel(hearing.averageLeftDBHL)), R \(dbLabel(hearing.averageRightDBHL))"
                    )
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(TennitusStyle.muted)
                }
            }
        }
    }

    private func contextRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(TennitusStyle.muted)
    }

    private func sync() {
        isSyncing = true
        message = nil
        Task {
            do {
                let context = try await healthReader.syncContext()
                await MainActor.run {
                    store.save(context)
                    message = "Synced Apple Health."
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }

    private func dbLabel(_ value: Double?) -> String {
        guard let value else { return "-- dB HL" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) dB HL"
    }
}

struct TriggerScoreCard: View {
    var score: WeightedTriggerScore

    var body: some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weighted trigger score")
                            .font(.headline)
                            .foregroundStyle(TennitusStyle.graphite)
                        Text("Local transparent heuristic, not AI weighting.")
                            .font(.caption)
                            .foregroundStyle(TennitusStyle.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int((score.score * 100).rounded()))")
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(TennitusStyle.primary)
                        Text(score.tier)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TennitusStyle.muted)
                    }
                }

                ForEach(score.factors) { factor in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(factor.name)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(Int((factor.weight * 100).rounded()))% x \(Int((factor.value * 100).rounded()))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(TennitusStyle.muted)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(TennitusStyle.background)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(TennitusStyle.primary)
                                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, factor.contribution / 0.25))))
                            }
                        }
                        .frame(height: 7)
                        Text(factor.evidence)
                            .font(.caption2)
                            .foregroundStyle(TennitusStyle.muted)
                    }
                }
            }
        }
    }
}
