import SwiftUI

struct ClinicalStatusBar: View {
    var leftText: String?
    var rightText: String?
    var leftActive: Bool = false

    var body: some View {
        HStack {
            if let leftText {
                HStack(spacing: 6) {
                    if leftActive {
                        Circle()
                            .fill(TennitusStyle.accent)
                            .frame(width: 6, height: 6)
                    }
                    Text(leftText)
                }
            }
            Spacer()
            if let rightText {
                Text(rightText)
                    .foregroundStyle(TennitusStyle.muted)
            }
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(leftActive ? TennitusStyle.accent : TennitusStyle.muted)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(padding)
        .background(TennitusStyle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TennitusStyle.border, lineWidth: 1)
        )
    }
}

enum AppTab: String, CaseIterable {
    case today = "TODAY"
    case trends = "TRENDS"
    case sounds = "SOUNDS"
    case reports = "REPORTS"
    case profile = "PROFILE"
}

struct ClinicalBottomNav: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(selection == tab ? TennitusStyle.primary : TennitusStyle.muted)
                        Circle()
                            .fill(selection == tab ? TennitusStyle.accent : TennitusStyle.surface2)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(TennitusStyle.surfaceElevated.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(TennitusStyle.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct AnimatedSpectrumBars: View {
    let barCount = 28
    @State private var phase = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(TennitusStyle.accent)
                    .frame(width: 4, height: height(for: index))
            }
        }
        .frame(height: 60)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let normalizedIndex = Double(index) / Double(barCount)
        let baseHeight = 10.0
        let sinValue = sin(normalizedIndex * .pi * 4 + phase)
        let cosValue = cos(normalizedIndex * .pi * 2 - phase)
        let randomNoise = sin(Double(index * 13) + phase * 2.5)

        let multiplier = max(0.2, (sinValue + cosValue + randomNoise) / 3.0 + 0.5)
        return baseHeight + (50.0 * multiplier)
    }
}

struct RotaryDialControl: View {
    @Binding var value: Double
    var bounds: ClosedRange<Double>
    var step: Double = 1.0
    var unit: String
    var format: (Double) -> String

    @State private var dragStartValue: Double?

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(TennitusStyle.surfaceElevated)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                Circle()
                    .stroke(TennitusStyle.border, lineWidth: 1)
                    .frame(width: 200, height: 200)

                // Tick marks
                ForEach(0..<60) { i in
                    Rectangle()
                        .fill(i % 5 == 0 ? TennitusStyle.muted : TennitusStyle.border)
                        .frame(width: 2, height: i % 5 == 0 ? 12 : 6)
                        .offset(y: -90)
                        .rotationEffect(.degrees(Double(i) * 6))
                }

                // Knob indicator based on current value relative to bounds
                Circle()
                    .fill(TennitusStyle.accent)
                    .frame(width: 12, height: 12)
                    .offset(y: -75)
                    .rotationEffect(.degrees(rotationAngle))

                VStack(spacing: 4) {
                    Text(format(value))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(TennitusStyle.primary)
                    Text(unit)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(TennitusStyle.muted)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { gesture in
                        if dragStartValue == nil {
                            dragStartValue = value
                        }
                        let delta = -Double(gesture.translation.height) / 5.0
                        setValue((dragStartValue ?? value) + delta * step)
                    }
                    .onEnded { _ in
                        dragStartValue = nil
                    }
            )
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    setValue(value + step)
                case .decrement:
                    setValue(value - step)
                @unknown default:
                    break
                }
            }

            // Optional fine controls
            HStack(spacing: 40) {
                Button {
                    setValue(value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .frame(width: 44, height: 44)
                        .background(TennitusStyle.surface, in: Circle())
                        .foregroundStyle(TennitusStyle.accent)
                }

                Button {
                    setValue(value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .frame(width: 44, height: 44)
                        .background(TennitusStyle.surface, in: Circle())
                        .foregroundStyle(TennitusStyle.accent)
                }
            }
        }
    }

    private func setValue(_ rawValue: Double) {
        let clamped = min(max(rawValue, bounds.lowerBound), bounds.upperBound)
        let stepped = bounds.lowerBound + ((clamped - bounds.lowerBound) / step).rounded() * step
        value = min(max(stepped, bounds.lowerBound), bounds.upperBound)
    }

    private var rotationAngle: Double {
        let fraction = (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return -120 + (fraction * 240) // sweep from -120 to +120
    }
}
