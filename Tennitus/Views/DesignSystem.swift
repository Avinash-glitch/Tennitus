import SwiftUI

enum TennitusStyle {
    static let background = Color(red: 0.075, green: 0.078, blue: 0.090)
    static let surface = Color.white.opacity(0.035)
    static let surface2 = Color.white.opacity(0.075)
    static let surfaceElevated = Color(red: 0.145, green: 0.149, blue: 0.168)
    static let primary = Color(red: 0.980, green: 0.984, blue: 0.992)
    static let accent = Color(red: 0.400, green: 0.890, blue: 0.890)
    static let warning = Color(red: 0.950, green: 0.670, blue: 0.250)
    static let destructive = Color(red: 0.920, green: 0.250, blue: 0.190)
    static let graphite = Color(red: 0.970, green: 0.975, blue: 0.985)
    static let muted = Color(red: 0.560, green: 0.585, blue: 0.630)
    static let border = Color.white.opacity(0.08)
}

struct AppScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                content
            }
            .padding(.vertical, 12)
        }
        .background(
            ZStack {
                TennitusStyle.background.ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [TennitusStyle.accent.opacity(0.12), .clear]), center: .topTrailing, startRadius: 0, endRadius: 400)
                    .ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [TennitusStyle.warning.opacity(0.08), .clear]), center: .bottomLeading, startRadius: 0, endRadius: 400)
                    .ignoresSafeArea()
            }
        )
        .foregroundStyle(TennitusStyle.graphite)
        .preferredColorScheme(.dark)
        .scrollIndicators(.hidden)
    }
}

struct AppHeader: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(TennitusStyle.accent)
            }
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(TennitusStyle.graphite)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(TennitusStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

struct AppSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .tracking(0.78)
                    .foregroundStyle(TennitusStyle.muted)
                    .padding(.horizontal, 6)
            }
            content
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppCard<Content: View>: View {
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(TennitusStyle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .foregroundStyle(TennitusStyle.graphite)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TennitusStyle.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

struct DividerStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
    }
}

struct PillButton: View {
    var title: String
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(active ? TennitusStyle.accent : TennitusStyle.surface)
                .foregroundStyle(active ? .black : TennitusStyle.graphite)
                .overlay(
                    Capsule()
                        .stroke(active ? TennitusStyle.accent : TennitusStyle.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AppButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case accent
        case danger
        case ghost
    }

    var variant: Variant = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: variant == .secondary ? 1 : 0)
            )
    }

    private var background: Color {
        switch variant {
        case .primary, .accent: TennitusStyle.accent
        case .secondary: TennitusStyle.surface
        case .danger: TennitusStyle.destructive
        case .ghost: Color.clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .accent: .black
        case .danger: .white
        case .secondary: TennitusStyle.graphite
        case .ghost: TennitusStyle.accent
        }
    }

    private var border: Color {
        variant == .secondary ? TennitusStyle.border : .clear
    }
}

struct StatBlock: View {
    var label: String
    var value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(TennitusStyle.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(TennitusStyle.graphite)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(TennitusStyle.muted)
                }
            }
        }
    }
}

struct MiniWaveView: View {
    var color = TennitusStyle.accent

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: CGFloat(6 + abs(sin(Double(index) * 0.7)) * 13 + abs(cos(Double(index) * 1.3)) * 7))
            }
        }
        .frame(width: 48, height: 30)
    }
}

struct SafetyNote: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(TennitusStyle.warning)
            Text(text)
                .font(.footnote)
                .foregroundStyle(TennitusStyle.graphite.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(TennitusStyle.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TennitusStyle.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct BackHeader: View {
    var parent: String
    var title: String
    var actionTitle: String?
    var onBack: () -> Void
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Label(parent, systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TennitusStyle.accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TennitusStyle.accent)
                    .buttonStyle(.plain)
            } else {
                Text("")
                    .frame(width: 52)
            }
        }
        .padding(.horizontal, 20)
    }
}
