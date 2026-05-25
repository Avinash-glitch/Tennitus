import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var healthReader = AppleHealthContextReader()
    @State private var showingDeleteConfirmation = false
    @State private var portableExportURL: URL?
    @State private var exportMessage: String?
    @State private var healthMessage: String?
    @State private var isSyncingHealth = false

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "SETTINGS",
                title: "Profile",
                subtitle: "Keep the tinnitus profile, privacy settings, and AI connection explicit."
            )

            AppSection("Tinnitus profile") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Laterality", selection: $store.profile.laterality) {
                            ForEach(TinnitusLaterality.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Sound type", selection: $store.profile.soundType) {
                            ForEach(SoundType.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Saved tone match")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(TennitusStyle.graphite)
                                Text(savedToneSummary)
                                    .font(.caption)
                                    .foregroundStyle(TennitusStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "waveform")
                                .foregroundStyle(TennitusStyle.primary)
                        }
                    }
                }
            }

            AppSection("Baseline") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsScaleRow(title: "Loudness", value: $store.profile.baselineLoudness)
                        SettingsScaleRow(title: "Distress", value: $store.profile.baselineDistress)
                        SettingsScaleRow(title: "Sleep impact", value: $store.profile.sleepImpact)
                    }
                }
            }
            
            AppSection("Clinical Safety") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.profile.redFlags?.hasRedFlags == true {
                            Text("Medical review recommended")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        } else if store.profile.redFlags != nil {
                            Text("No red flags reported")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Text("Safety screening not completed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        NavigationLink {
                            RedFlagScreeningView()
                        } label: {
                            Label("Update screening", systemImage: "stethoscope")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))
                    }
                }
            }



            AppSection("Apple Health") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Link sleep duration and Apple audiogram hearing-test samples as context for trends and AI summaries.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            syncAppleHealthContext()
                        } label: {
                            Label(isSyncingHealth ? "Syncing..." : "Sync sleep and hearing", systemImage: "heart.text.square")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))
                        .disabled(isSyncingHealth)

                        if let sleep = store.appleHealthContext.sleep {
                            Text("Sleep: latest \(sleep.latestNightAsleepHours.formatted(.number.precision(.fractionLength(1))))h, \(sleep.lookbackDays)-day avg \(sleep.averageAsleepHours.formatted(.number.precision(.fractionLength(1))))h")
                                .font(.caption)
                                .foregroundStyle(TennitusStyle.muted)
                        }

                        if let hearing = store.appleHealthContext.hearing {
                            Text("Hearing: latest audiogram \(hearingDateLabel(hearing.latestAudiogramDate)), L \(dbLabel(hearing.averageLeftDBHL)), R \(dbLabel(hearing.averageRightDBHL))")
                                .font(.caption)
                                .foregroundStyle(TennitusStyle.muted)
                        }

                        if let healthMessage {
                            Text(healthMessage)
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.muted)
                        }
                    }
                }
            }

            AppSection("Privacy") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tennitus stores MVP data locally on this device. Cloud sync and AI are optional for the current build.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            generatePortableExport()
                        } label: {
                            Label("Export portable data", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))

                        if let portableExportURL {
                            ShareLink(item: portableExportURL) {
                                Label("Share export file", systemImage: "doc.badge.arrow.up")
                            }
                            .buttonStyle(AppButtonStyle(variant: .secondary))
                        }

                        if let exportMessage {
                            Text(exportMessage)
                                .font(.footnote)
                                .foregroundStyle(TennitusStyle.muted)
                        }

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete local data", systemImage: "trash")
                        }
                        .buttonStyle(AppButtonStyle(variant: .danger))
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete local data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAllData()
            }
        } message: {
            Text("This removes local profile, check-in, spike, lab event, and audiogram data from this device.")
        }
    }

    private var savedToneSummary: String {
        guard let frequency = store.profile.savedToneFrequencyHz else {
            return "No saved match yet"
        }

        let waveform = store.profile.savedToneWaveform?.rawValue ?? ToneWaveform.sine.rawValue
        let low = store.profile.toneMatchLowHz ?? 125
        let high = store.profile.toneMatchHighHz ?? 12_000
        return "\(formatHz(frequency)) · \(waveform) · \(formatHz(low))-\(formatHz(high))"
    }

    private func formatHz(_ hz: Double) -> String {
        hz >= 1_000 ? "\((hz / 1_000).formatted(.number.precision(.fractionLength(1)))) kHz" : "\(Int(hz)) Hz"
    }

    private func generatePortableExport() {
        do {
            portableExportURL = try PortableDataExportService.generate(store: store, includeAudio: true)
            exportMessage = "Export includes profile, tone match, logs, audio-event features, and audio recordings when files are available."
        } catch {
            exportMessage = error.localizedDescription
        }
    }



    private func syncAppleHealthContext() {
        isSyncingHealth = true
        healthMessage = nil
        Task {
            do {
                let context = try await healthReader.syncContext()
                await MainActor.run {
                    store.save(context)
                    healthMessage = "Synced Apple Health context."
                    isSyncingHealth = false
                }
            } catch {
                await MainActor.run {
                    healthMessage = error.localizedDescription
                    isSyncingHealth = false
                }
            }
        }
    }

    private func hearingDateLabel(_ date: Date?) -> String {
        guard let date else { return "none" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dbLabel(_ value: Double?) -> String {
        guard let value else { return "-- dB HL" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) dB HL"
    }
}

private struct SettingsScaleRow: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TennitusStyle.graphite)
                Spacer()
                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(TennitusStyle.primary)
            }
            Slider(value: Binding(get: {
                Double(value)
            }, set: {
                value = Int($0.rounded())
            }), in: 0...10, step: 1)
        }
    }
}

struct RedFlagScreeningView: View {
    @EnvironmentObject private var store: AppStore
    @State private var result = RedFlagScreeningResult()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("Have you experienced any of these recently?").font(.subheadline)) {
                Toggle("Pulsatile or heartbeat-synced sound", isOn: $result.heartbeatSynced)
                Toggle("Sudden hearing loss", isOn: $result.suddenHearingLoss)
                Toggle("New onset in only one ear", isOn: $result.oneSidedNew)
                Toggle("Dizziness or vertigo", isOn: $result.dizziness)
                Toggle("Ear pain or drainage", isOn: $result.earPain)
                Toggle("Neurological symptoms (e.g. weakness, numbness)", isOn: $result.neurologicalSymptoms)
                Toggle("Severe distress or feeling unsafe", isOn: $result.severeDistress)
            }
            
            Section {
                Button("Save screening") {
                    result.answeredAt = Date()
                    store.profile.redFlags = result
                    dismiss()
                }
            }
        }
        .navigationTitle("Safety Screening")
        .onAppear {
            if let existing = store.profile.redFlags {
                result = existing
            }
        }
    }
}
