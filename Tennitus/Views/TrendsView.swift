import Charts
import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "PATTERNS",
                title: "Trends",
                subtitle: "Weekly associations across loudness, distress, sleep, stress, spikes, and tracking consistency."
            )

            AppSection("Weekly summary") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.weeklyInsight.headline)
                            .font(.headline)
                            .foregroundStyle(TennitusStyle.graphite)

                        HStack(spacing: 12) {
                            StatBlock(label: "Confidence", value: store.weeklyInsight.confidence, unit: nil)
                            StatBlock(label: "Check-ins", value: "\(store.weeklyInsight.checkInCount)", unit: nil)
                            StatBlock(label: "Spikes", value: "\(store.weeklyInsight.spikeCount)", unit: nil)
                        }

                        Divider()

                        ForEach(store.weeklyInsight.observations, id: \.self) { observation in
                            Label(observation, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            AppSection("Trigger weighting") {
                TriggerScoreCard(score: TriggerWeightingEngine.calculate(store: store))
            }

            AppSection("Apple Health") {
                HealthSyncCard()
            }

            AppSection("Loudness and distress") {
                AppCard(padding: 16) {
                    Chart(store.checkIns.sorted { $0.date < $1.date }) { checkIn in
                        LineMark(
                            x: .value("Date", checkIn.date),
                            y: .value("Loudness", checkIn.loudness)
                        )
                        .foregroundStyle(TennitusStyle.primary)

                        LineMark(
                            x: .value("Date", checkIn.date),
                            y: .value("Distress", checkIn.distress)
                        )
                        .foregroundStyle(TennitusStyle.accent)
                    }
                    .chartYScale(domain: 0...10)
                    .frame(height: 220)

                    HStack(spacing: 14) {
                        legend("Loudness", color: TennitusStyle.primary)
                        legend("Distress", color: TennitusStyle.accent)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            }

            AppSection("Data quality") {
                AppCard(padding: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        StatBlock(label: "All check-ins", value: "\(store.checkIns.count)", unit: nil)
                        StatBlock(label: "All spikes", value: "\(store.spikes.count)", unit: nil)
                        StatBlock(label: "Avg sleep", value: store.weeklyInsight.averageSleep.formatted(.number.precision(.fractionLength(1))), unit: "/10")
                        StatBlock(label: "Avg stress", value: store.weeklyInsight.averageStress.formatted(.number.precision(.fractionLength(1))), unit: "/10")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}
