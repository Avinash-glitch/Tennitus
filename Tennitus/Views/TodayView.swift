import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft = DailyCheckIn()
    @State private var spikeDraft = SpikeLog()
    @State private var showingSpikeLog = false
    @State private var showingEventLogger = false
    @State private var showingProfileEditor = false
    @State private var showingLab = false

    var body: some View {
        AppScreen {
            // Header
            AppHeader(
                eyebrow: "PROFILE · \(store.detectedSubtype.primary.rawValue) · \(Date().formatted(.dateTime.month().day().year()))",
                title: "Today's Pulse.",
                subtitle: nil
            )

            // Primary Status Card
            AppSection {
                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DISTRESS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TennitusStyle.muted)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("\(latestDistress)")
                                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                                        .foregroundStyle(latestDistress > 6 ? TennitusStyle.warning : TennitusStyle.accent)
                                    Text("/10")
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundStyle(TennitusStyle.muted)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("PEAK FREQUENCY")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TennitusStyle.muted)
                                Text(store.profile.savedToneFrequencyHz != nil ? "\(Int(store.profile.savedToneFrequencyHz!)) Hz" : "-- Hz")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TennitusStyle.accent)
                            }
                        }

                        Divider().background(TennitusStyle.border)

                        Text(store.weeklyInsight.headline)
                            .font(.subheadline)
                            .foregroundStyle(TennitusStyle.graphite)
                    }
                }
            }

            // Quick Actions
            AppSection {
                HStack(spacing: 12) {
                    Button {
                        showingEventLogger = true
                    } label: {
                        GlassPanel(padding: 16) {
                            VStack(alignment: .leading) {
                                Text("LOG EVENT")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(TennitusStyle.muted)
                                Spacer()
                                HStack(alignment: .bottom) {
                                    Circle()
                                        .fill(TennitusStyle.accent)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: TennitusStyle.accent, radius: 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(TennitusStyle.background)
                                                .frame(width: 12, height: 12)
                                        )
                                    Spacer()
                                    Text("→")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(TennitusStyle.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 80) // To match h-28 roughly (112pt) minus padding
                        }
                    }
                    .buttonStyle(GlassyCardButtonStyle())

                    Button {
                        showingLab = true
                    } label: {
                        GlassPanel(padding: 16) {
                            VStack(alignment: .leading) {
                                Text("TONE MATCH")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(TennitusStyle.muted)
                                Spacer()
                                HStack(alignment: .bottom) {
                                    Circle()
                                        .stroke(TennitusStyle.accent, lineWidth: 1)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text("Hz")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(TennitusStyle.accent)
                                        )
                                    Spacer()
                                    Text("→")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(TennitusStyle.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 80)
                        }
                    }
                    .buttonStyle(GlassyCardButtonStyle())
                }
            }

            // 7-day history
            AppSection("7-Day Distress Trend") {
                GlassPanel {
                    let recentDistress = last7DaysDistress
                    if recentDistress.isEmpty {
                        Text("No check-ins yet. Log your first event to see trends.")
                            .font(.subheadline)
                            .foregroundStyle(TennitusStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(0..<recentDistress.count, id: \.self) { i in
                                let isToday = i == recentDistress.count - 1
                                let value = recentDistress[i]
                                let height = max(4, CGFloat(value) * 6)
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isToday ? TennitusStyle.accent : TennitusStyle.accent.opacity(0.3))
                                        .frame(width: 24, height: height)
                                    Text("\(Int(value))")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(TennitusStyle.muted)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }

            // Older sections moved to bottom in a DisclosureGroup
            DisclosureGroup("Legacy Data & Settings") {
                VStack(spacing: 20) {
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
                            .foregroundStyle(TennitusStyle.accent)
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
                        GlassPanel(padding: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                ScaleRow(title: "Loudness", value: $draft.loudness)
                                ScaleRow(title: "Distress", value: $draft.distress)
                                ScaleRow(title: "Sleep quality", value: $draft.sleepQuality)
                                ScaleRow(title: "Stress", value: $draft.stress)
                                ScaleRow(title: "Mood", value: $draft.mood)

                                Divider().background(TennitusStyle.border)

                                Picker("Headphones", selection: $draft.headphoneUse) {
                                    ForEach(DurationBucket.allCases) { bucket in
                                        Text(bucket.rawValue).tag(bucket)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(TennitusStyle.accent)

                                Picker("Noise exposure", selection: $draft.noiseExposure) {
                                    ForEach(ExposureBucket.allCases) { bucket in
                                        Text(bucket.rawValue).tag(bucket)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(TennitusStyle.accent)

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
                        GlassPanel(padding: 16) {
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
                                            .foregroundStyle(TennitusStyle.muted)
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
                                    .foregroundStyle(TennitusStyle.muted)
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }
            .accentColor(TennitusStyle.accent)
            .padding(.horizontal, 20)
            .padding(.bottom, 80) // Add bottom padding for clinical nav safe area
        }
        .fullScreenCover(isPresented: $showingEventLogger) {
            EventLoggerView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingLab) {
            LabView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingSpikeLog) {
            SpikeLogView(spike: $spikeDraft) {
                store.save(spikeDraft)
                showingSpikeLog = false
            }
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

    private var latestDistress: Int {
        if let latest = store.latestCheckIn, Calendar.current.isDateInToday(latest.date) {
            return latest.distress
        }
        return 0
    }

    private var last7DaysDistress: [Double] {
        let recent = store.checkIns.sorted { $0.date > $1.date }.prefix(7)
        return Array(recent).reversed().map { Double($0.distress) }
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
                    .foregroundStyle(TennitusStyle.accent)
            }
            Slider(value: Binding(get: {
                Double(value)
            }, set: {
                value = Int($0.rounded())
            }), in: 0...10, step: 1)
            .accentColor(TennitusStyle.accent)
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
                    GlassPanel(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            ScaleRow(title: "Current loudness", value: $spike.loudness)
                            ScaleRow(title: "Current distress", value: $spike.distress)
                            TextField("Context", text: $spike.context)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                AppSection("Recent triggers") {
                    GlassPanel(padding: 16) {
                        TriggerChipGrid(spike: $spike)
                    }
                }

                AppSection("Note") {
                    GlassPanel(padding: 16) {
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
                    .foregroundStyle(TennitusStyle.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .foregroundStyle(TennitusStyle.accent)
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
        GlassPanel(padding: 16) {
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
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(TennitusStyle.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(TennitusStyle.accent.opacity(0.10), in: Capsule())
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

                Divider().background(TennitusStyle.border)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Label(isExpanded ? "Hide Evidence & Science" : "Show Evidence & Science", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TennitusStyle.accent)
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
                                    .foregroundStyle(TennitusStyle.accent)
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
        case .tonal: return TennitusStyle.accent
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

private struct GlassyCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
