import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft = DailyCheckIn()
    @State private var spikeDraft = SpikeLog()
    @State private var showingSpikeLog = false
    @State private var showingEventLogger = false
    @State private var showingProfileEditor = false

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "TODAY",
                title: "Tennitus",
                subtitle: store.weeklyInsight.headline
            )

            AppSection {
                Button {
                    showingEventLogger = true
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(TennitusStyle.primary)
                                .frame(width: 88, height: 88)
                                .shadow(color: TennitusStyle.primary.opacity(0.32), radius: 12, x: 0, y: 6)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(spacing: 4) {
                            Text("Log event")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(TennitusStyle.graphite)
                            Text("Distress, loudness, context, and audio in one flow")
                                .font(.subheadline)
                                .foregroundStyle(TennitusStyle.muted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [
                                    .white.opacity(0.75),
                                    TennitusStyle.primary.opacity(0.35),
                                    TennitusStyle.accent.opacity(0.25)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: TennitusStyle.primary.opacity(0.18), radius: 22, x: 0, y: 14)
                }
                .buttonStyle(.plain)
            }

            AppSection {
                HStack(alignment: .bottom) {
                    Text("PATTERN PROFILE")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(0.78)
                        .foregroundStyle(TennitusStyle.muted)
                        .padding(.horizontal, 6)
                    Spacer()
                    Button("Set Profile") {
                        showingProfileEditor = true
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TennitusStyle.primary)
                    .padding(.horizontal, 6)
                }
                TinnitusSubtypeCard(subtype: store.detectedSubtype)
                SafetyNote(text: "This pattern profile is based on self-reported tracking data. It is not a clinical diagnosis or medical assessment.")
            }

            AppSection("Health context") {
                HealthSyncCard()
            }

            AppSection("Trigger weighting") {
                TriggerScoreCard(score: TriggerWeightingEngine.calculate(store: store))
            }

            AppSection("Daily check-in") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        ScaleRow(title: "Loudness", value: $draft.loudness)
                        ScaleRow(title: "Distress", value: $draft.distress)
                        ScaleRow(title: "Sleep quality", value: $draft.sleepQuality)
                        ScaleRow(title: "Stress", value: $draft.stress)
                        ScaleRow(title: "Mood", value: $draft.mood)

                        Divider()

                        Picker("Headphones", selection: $draft.headphoneUse) {
                            ForEach(DurationBucket.allCases) { bucket in
                                Text(bucket.rawValue).tag(bucket)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Noise exposure", selection: $draft.noiseExposure) {
                            ForEach(ExposureBucket.allCases) { bucket in
                                Text(bucket.rawValue).tag(bucket)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Optional note", text: $draft.notes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            store.save(draft)
                        } label: {
                            Label("Save check-in", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(AppButtonStyle(variant: .primary))
                    }
                }
            }

            AppSection("Spike support") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.heart")
                                .font(.title3)
                                .foregroundStyle(TennitusStyle.warning)
                                .frame(width: 42, height: 42)
                                .background(TennitusStyle.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Log a spike")
                                    .font(.headline)
                                    .foregroundStyle(TennitusStyle.graphite)
                                Text("Capture triggers while the context is still fresh.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            spikeDraft = SpikeLog()
                            showingSpikeLog = true
                        } label: {
                            Label("Log spike", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(AppButtonStyle(variant: .secondary))

                        Text("For severe distress or feeling unsafe, use local emergency or crisis support. Tennitus does not provide emergency triage.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSpikeLog) {
            SpikeLogView(spike: $spikeDraft) {
                store.save(spikeDraft)
                showingSpikeLog = false
            }
        }
        .fullScreenCover(isPresented: $showingEventLogger) {
            EventLoggerView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingProfileEditor) {
            NavigationStack {
                ProfileEditorView()
            }
        }
        .onAppear {
            if let latest = store.latestCheckIn, Calendar.current.isDateInToday(latest.date) {
                draft = latest
            }
        }
    }
}

private struct ScaleRow: View {
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

private struct SpikeLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var spike: SpikeLog
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            AppScreen {
                AppHeader(
                    eyebrow: "SPIKE",
                    title: "Log Spike",
                    subtitle: "Record severity, context, and likely triggers for later pattern review."
                )

                AppSection("Severity") {
                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            ScaleRow(title: "Current loudness", value: $spike.loudness)
                            ScaleRow(title: "Current distress", value: $spike.distress)
                            TextField("Context", text: $spike.context)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                AppSection("Recent triggers") {
                    AppCard(padding: 16) {
                        TriggerChipGrid(spike: $spike)
                    }
                }

                AppSection("Note") {
                    AppCard(padding: 16) {
                        TextField("Optional note", text: $spike.notes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

private struct TriggerChipGrid: View {
    @Binding var spike: SpikeLog

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(TriggerTag.allCases) { trigger in
                PillButton(title: trigger.rawValue, active: spike.triggers.contains(trigger)) {
                    if spike.triggers.contains(trigger) {
                        spike.triggers.remove(trigger)
                    } else {
                        spike.triggers.insert(trigger)
                    }
                }
            }
        }
    }
}

private struct TinnitusSubtypeCard: View {
    let subtype: TinnitusSubtype
    @State private var isExpanded = false

    var body: some View {
        AppCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(primaryColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: iconName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primaryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(subtype.primary.rawValue)
                                .font(.headline)
                                .foregroundStyle(TennitusStyle.graphite)
                            
                            if let pitch = subtype.pitchHz {
                                Text(formatHz(pitch))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TennitusStyle.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(TennitusStyle.primary.opacity(0.10), in: Capsule())
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Text("Confidence:")
                                .font(.caption)
                                .foregroundStyle(TennitusStyle.muted)
                            Text(subtype.confidence.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(confidenceColor)
                        }
                    }
                    Spacer()
                }

                if !subtype.modifiers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(subtype.modifiers).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { modifier in
                                Text(modifier.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(TennitusStyle.surface2, in: Capsule())
                                    .foregroundStyle(TennitusStyle.graphite)
                            }
                        }
                    }
                }

                if subtype.primary == .pulsatile {
                    SafetyNote(text: "Pulsatile symptoms can be associated with vascular conditions. We strongly recommend having this evaluated by an audiologist or ENT specialist.")
                }

                Divider()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Label(isExpanded ? "Hide Evidence & Science" : "Show Evidence & Science", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TennitusStyle.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Evidence used for this classification:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TennitusStyle.muted)
                            .padding(.top, 4)
                        
                        ForEach(subtype.evidence, id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(TennitusStyle.primary)
                                Text(item)
                                    .font(.caption)
                                    .foregroundStyle(TennitusStyle.graphite.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Text("How to update: Continue recording daily check-ins and spike context to refine your profile. Modifiers update dynamically based on your logs.")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(TennitusStyle.muted)
                            .padding(.top, 4)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var iconName: String {
        switch subtype.primary {
        case .tonal: return "bell.ring.fill"
        case .narrowbandNoise: return "wind"
        case .pulsatile: return "pulse.circle.fill"
        case .complex: return "waveform"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var primaryColor: Color {
        switch subtype.primary {
        case .tonal: return TennitusStyle.primary
        case .narrowbandNoise: return TennitusStyle.accent
        case .pulsatile: return TennitusStyle.warning
        case .complex: return Color.purple
        case .unknown: return TennitusStyle.muted
        }
    }

    private var confidenceColor: Color {
        switch subtype.confidence {
        case .high: return .green
        case .medium: return TennitusStyle.accent
        case .low: return TennitusStyle.muted
        }
    }

    private func formatHz(_ hz: Double) -> String {
        hz >= 1000 ? String(format: "%.1f kHz", hz / 1000.0) : "\(Int(hz)) Hz"
    }
}
