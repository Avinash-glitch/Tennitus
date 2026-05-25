import SwiftUI

struct SoundsView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var player = SoundPlayer()
    @State private var timerMinutes = 20

    private let timers = [5, 10, 20, 30, 60]

    var body: some View {
        AppScreen {
            AppHeader(
                eyebrow: "MASKING",
                title: "Comfort Sounds",
                subtitle: "Basic masking presets for low-volume comfort sessions and focus support."
            )

            AppSection("Sound") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Preset", selection: $player.preset) {
                            ForEach(MaskingSoundPreset.allCases) { sound in
                                Text(sound.rawValue).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack(spacing: 14) {
                            Image(systemName: soundIcon)
                                .font(.title2)
                                .foregroundStyle(TennitusStyle.primary)
                                .frame(width: 52, height: 52)
                                .background(TennitusStyle.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.preset.rawValue)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(TennitusStyle.graphite)
                                if let remainingSeconds = player.remainingSeconds {
                                    Text("Stops in \(remainingSeconds / 60)m \(remainingSeconds % 60)s")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(timerMinutes) minute timer")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }

                        Button {
                            player.toggle(timerMinutes: timerMinutes)
                        } label: {
                            Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        }
                        .buttonStyle(AppButtonStyle(variant: player.isPlaying ? .secondary : .primary))
                        
                        if let notch = player.notchFrequencyHz {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.badge.minus")
                                    .foregroundStyle(TennitusStyle.primary)
                                    .font(.footnote)
                                Text("Personalized notch filter active at \(Int(notch)) Hz")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }

            AppSection("Controls") {
                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Volume")
                                Spacer()
                                Text("\(Int(player.volume * 100))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            Slider(value: $player.volume, in: 0...1, step: 0.01)
                        }

                        Picker("Timer", selection: $timerMinutes) {
                            ForEach(timers, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            AppSection {
                SafetyNote(text: "Use sounds at a comfortable volume. These sounds are for comfort and focus support, not treatment.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            player.stop()
        }
        .onAppear {
            updatePlayerNotch()
        }
        .onChange(of: store.detectedSubtype) { _ in
            updatePlayerNotch()
        }
    }
    
    private func updatePlayerNotch() {
        if store.detectedSubtype.primary == .tonal, let pitch = store.detectedSubtype.pitchHz {
            player.notchFrequencyHz = pitch
        } else {
            player.notchFrequencyHz = nil
        }
    }

    private var soundIcon: String {
        switch player.preset {
        case .whiteNoise, .pinkNoise, .brownNoise:
            return "waveform"
        case .softRain:
            return "cloud.rain"
        case .ocean:
            return "water.waves"
        case .fan:
            return "wind"
        }
    }
}
