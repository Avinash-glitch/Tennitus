import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var healthReader = AppleHealthContextReader()
    @StateObject private var referencePlayer = TinnitusReferenceSoundPlayer()
    @State private var showingDeleteConfirmation = false
    @State private var portableExportURL: URL?
    @State private var exportMessage: String?
    @State private var healthMessage: String?
    @State private var isSyncingHealth = false

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "ACCOUNT · LOCAL-ONLY",
                title: "Profile",
                subtitle: "\(store.checkIns.count) check-ins · \(store.audioEvents.count) events"
            )

            AppSection {
                GlassPanel(padding: 0) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ProfileEditorView()
                        } label: {
                            SettingsRow(label: "Tinnitus Profile", value: savedToneSummary, muted: false)
                        }
                        .buttonStyle(.plain)

                        Divider().background(TennitusStyle.border)

                        NavigationLink {
                            RedFlagScreeningView()
                        } label: {
                            SettingsRow(label: "Clinical Safety", value: safetyStatus, muted: false)
                        }
                        .buttonStyle(.plain)

                        Divider().background(TennitusStyle.border)

                        Button {
                            syncAppleHealthContext()
                        } label: {
                            SettingsRow(label: "Apple Health", value: isSyncingHealth ? "Syncing..." : (store.appleHealthContext.sleep != nil ? "Connected" : "Tap to connect"), muted: false)
                        }
                        .buttonStyle(.plain)

                        if !store.appleHealthContext.dataPoints.isEmpty {
                            Divider().background(TennitusStyle.border)
                            NavigationLink {
                                AppleHealthHistoryView(dataPoints: store.appleHealthContext.dataPoints)
                            } label: {
                                SettingsRow(label: "Audiogram & History", value: "\(store.appleHealthContext.dataPoints.count) records", muted: false)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().background(TennitusStyle.border)

                        Button {
                            generatePortableExport()
                        } label: {
                            SettingsRow(label: "Export Data", value: "CSV · JSON", muted: true)
                        }
                        .buttonStyle(.plain)

                        if let portableExportURL {
                            Divider().background(TennitusStyle.border)
                            ShareLink(item: portableExportURL) {
                                SettingsRow(label: "Share Export", value: "Ready", muted: false)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().background(TennitusStyle.border)

                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            SettingsRow(label: "Delete Data", value: "Local only", muted: true)
                        }
                        .buttonStyle(.plain)

                        Divider().background(TennitusStyle.border)

                        SettingsRow(label: "About Tennitus", value: "v4.2.1", muted: true)
                    }
                }
            }

            if let exportMessage {
                AppSection {
                    Text(exportMessage)
                        .font(.footnote)
                        .foregroundStyle(TennitusStyle.muted)
                }
            }

            if let healthMessage {
                AppSection {
                    Text(healthMessage)
                        .font(.footnote)
                        .foregroundStyle(TennitusStyle.muted)
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
        .onDisappear {
            referencePlayer.stop()
        }
    }

    private var savedToneSummary: String {
        guard let frequency = store.profile.savedToneFrequencyHz else {
            return "No match"
        }
        return formatHz(frequency)
    }

    private var safetyStatus: String {
        guard let redFlags = store.profile.redFlags else {
            return "Not completed"
        }
        return redFlags.hasRedFlags ? "Review needed" : "Completed"
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

private struct SettingsRow: View {
    var label: String
    var value: String
    var muted: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TennitusStyle.graphite)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(muted ? TennitusStyle.muted : TennitusStyle.primary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

private struct TinnitusSoundReferencePicker: View {
    @Binding var selectedType: SoundType
    let playingType: SoundType?
    let onPlay: (SoundType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference sounds")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TennitusStyle.graphite)
                    Text("Compare softly, then choose the closest match.")
                        .font(.caption)
                        .foregroundStyle(TennitusStyle.muted)
                }
                Spacer()
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(SoundType.allCases) { type in
                    ReferenceSoundButton(
                        type: type,
                        isSelected: selectedType == type,
                        isPlaying: playingType == type,
                        select: { selectedType = type },
                        play: { onPlay(type) }
                    )
                }
            }
        }
        .padding(.top, 2)
    }
}

private struct ReferenceSoundButton: View {
    let type: SoundType
    let isSelected: Bool
    let isPlaying: Bool
    let select: () -> Void
    let play: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                Text(type.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? TennitusStyle.primary : TennitusStyle.graphite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: play) {
                Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isPlaying ? TennitusStyle.warning : TennitusStyle.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(TennitusStyle.primary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop \(type.rawValue) reference" : "Play \(type.rawValue) reference")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? TennitusStyle.primary.opacity(0.10) : Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? TennitusStyle.primary.opacity(0.45) : TennitusStyle.border, lineWidth: 1)
        )
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

struct ProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var referencePlayer = TinnitusReferenceSoundPlayer()

    var body: some View {
        AppScreen {
            AppSection("Tinnitus profile") {
                GlassPanel(padding: 16) {
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

                        TinnitusSoundReferencePicker(
                            selectedType: $store.profile.soundType,
                            playingType: referencePlayer.playingType,
                            onPlay: { referencePlayer.toggle($0) }
                        )

                        Divider().background(TennitusStyle.border)

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
                GlassPanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsScaleRow(title: "Loudness", value: $store.profile.baselineLoudness)
                        SettingsScaleRow(title: "Distress", value: $store.profile.baselineDistress)
                        SettingsScaleRow(title: "Sleep impact", value: $store.profile.sleepImpact)
                    }
                }
            }
        }
        .navigationTitle("Set Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.body.weight(.semibold))
            }
        }
        .onDisappear {
            referencePlayer.stop()
        }
    }

    private var savedToneSummary: String {
        if let hz = store.profile.savedToneFrequencyHz, let wave = store.profile.savedToneWaveform {
            return "\(Int(hz)) Hz (\(wave.rawValue.lowercased()))"
        }
        return "None saved"
    }
}
