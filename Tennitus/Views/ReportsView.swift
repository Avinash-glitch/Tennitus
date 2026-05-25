import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var range = 14
    @State private var reportURL: URL?
    @State private var generationError: String?

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "CLINIC PACK",
                title: "Reports",
                subtitle: "Create a concise PDF from check-ins, spikes, lab events, weekly insights, and indicative audiogram data."
            )

            AppSection("Report range") {
                AppCard(padding: 16) {
                    Picker("Days", selection: $range) {
                        Text("7D").tag(7)
                        Text("14D").tag(14)
                        Text("30D").tag(30)
                        Text("90D").tag(90)
                    }
                    .pickerStyle(.segmented)
                }
            }

            AppSection("Preview") {
                AppCard {
                    reportRow(title: "Daily check-ins", value: "\(store.checkIns.count)", icon: "checkmark.circle")
                    divider
                    reportRow(title: "Spike logs", value: "\(store.spikes.count)", icon: "bolt.circle")
                    divider
                    reportRow(title: "Lab sound events", value: "\(store.audioEvents.count)", icon: "waveform.path.ecg")
                    divider
                    reportRow(title: "Audiogram", value: store.latestAudiogram.points.isEmpty ? "Not added" : "Saved", icon: "ear")
                    divider
                    reportRow(title: "Insight confidence", value: store.weeklyInsight.confidence, icon: "sparkles")
                }
            }

            AppSection("Weekly insight") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.weeklyInsight.headline)
                            .font(.headline)
                            .foregroundStyle(TennitusStyle.graphite)
                        Text(store.weeklyInsight.observations.joined(separator: " "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            AppSection("Audiogram") {
                NavigationLink {
                    AudiogramView()
                } label: {
                    AppCard {
                        HStack(spacing: 14) {
                            Image(systemName: "ear.badge.waveform")
                                .font(.title3)
                                .foregroundStyle(TennitusStyle.primary)
                                .frame(width: 42, height: 42)
                                .background(TennitusStyle.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Indicative audiogram")
                                    .font(.headline)
                                    .foregroundStyle(TennitusStyle.graphite)
                                Text("ASHA-style severity tier, PDF export, and Apple Health save")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)
            }

            AppSection("Export") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            do {
                                reportURL = try ReportRenderer.generate(rangeDays: range, store: store)
                                generationError = nil
                            } catch {
                                generationError = error.localizedDescription
                            }
                        } label: {
                            Label("Generate PDF", systemImage: "doc.richtext")
                        }
                        .buttonStyle(AppButtonStyle(variant: .primary))

                        if let reportURL {
                            ShareLink(item: reportURL) {
                                Label("Share report", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(AppButtonStyle(variant: .secondary))
                        }

                        if let generationError {
                            Text(generationError)
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.warning)
                        }
                    }
                }
            }

            AppSection {
                SafetyNote(text: "Reports use self-reported tracking data and device recordings. They are intended for appointment preparation, not diagnosis.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 64)
    }

    private func reportRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TennitusStyle.primary)
                .frame(width: 42, height: 42)
                .background(TennitusStyle.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TennitusStyle.graphite)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
