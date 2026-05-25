import SwiftUI

enum TennitusStyle {
    static let background = Color(red: 0.969, green: 0.980, blue: 0.976)
    static let surface = Color.white
    static let surface2 = Color(red: 0.957, green: 0.965, blue: 0.969)
    static let primary = Color(red: 0.059, green: 0.463, blue: 0.431)
    static let accent = Color(red: 0.851, green: 0.467, blue: 0.024)
    static let warning = Color(red: 0.780, green: 0.180, blue: 0.120)
    static let graphite = Color(red: 0.125, green: 0.161, blue: 0.216)
    static let muted = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let border = Color(red: 0.839, green: 0.871, blue: 0.890)
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
        .background(TennitusStyle.background.ignoresSafeArea())
        .foregroundStyle(TennitusStyle.graphite)
        .preferredColorScheme(.light)
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
                Text(eyebrow)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(TennitusStyle.muted)
            }
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .default))
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
        .background(TennitusStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(TennitusStyle.graphite)
        .shadow(color: Color(red: 0.059, green: 0.118, blue: 0.157).opacity(0.12), radius: 24, x: 0, y: 8)
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
                .background(active ? TennitusStyle.primary : TennitusStyle.surface)
                .foregroundStyle(active ? .white : TennitusStyle.graphite)
                .overlay(
                    Capsule()
                        .stroke(active ? TennitusStyle.primary : TennitusStyle.border, lineWidth: 1)
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
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(border, lineWidth: variant == .secondary ? 1 : 0)
            )
    }

    private var background: Color {
        switch variant {
        case .primary: TennitusStyle.primary
        case .secondary: TennitusStyle.surface
        case .accent: TennitusStyle.accent
        case .danger: TennitusStyle.warning
        case .ghost: Color.clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .accent, .danger: .white
        case .secondary: TennitusStyle.graphite
        case .ghost: TennitusStyle.primary
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
    var color = TennitusStyle.primary

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
        .background(TennitusStyle.warning.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TennitusStyle.warning.opacity(0.22), lineWidth: 1)
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
                    .foregroundStyle(TennitusStyle.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TennitusStyle.primary)
                    .buttonStyle(.plain)
            } else {
                Text("")
                    .frame(width: 52)
            }
        }
        .padding(.horizontal, 20)
    }
}
