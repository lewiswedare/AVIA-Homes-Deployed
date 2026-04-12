import SwiftUI

enum AVIATheme {
    static let aviaBlack = Color(hex: "1A1A1A")
    static let aviaWhite = Color(hex: "E1DDDC")
    static let timelessBrown = Color(hex: "37332B")

    static let teal = Color(hex: "37332B")
    static let tealLight = Color(hex: "4A453B")
    static let tealDark = Color(hex: "2A261F")
    static let tealBright = Color(hex: "37332B")
    static let tealSubtle = Color(hex: "37332B").opacity(0.08)

    static let background = Color(hex: "E1DDDC")
    static let cardBackground = Color(hex: "EBE8E7")
    static let cardBackgroundAlt = Color(hex: "F2F0EF")
    static let surfaceElevated = Color(hex: "D8D4D3")
    static let surfaceBorder = Color(hex: "CDC9C7")

    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "5C5856")
    static let textTertiary = Color(hex: "8A8583")

    static let accent = timelessBrown
    static let success = Color(hex: "2D7A3A")
    static let warning = Color(hex: "C67A1A")
    static let destructive = Color(hex: "C93B3B")

    static let tealGradient = LinearGradient(
        colors: [Color(hex: "1A1A1A"), Color(hex: "37332B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGradient = LinearGradient(
        colors: [Color(hex: "EBE8E7"), Color(hex: "E1DDDC")],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

struct BentoCard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

struct AVIACard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.neueCaption2Medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

struct BentoIconCircle: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.neueCorpMedium(14))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }
}

struct AVIAMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BentoIconCircle(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(subtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(1)
            }
            Text(title)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}

struct PremiumButton: View {
    let title: String
    let icon: String?
    let style: ButtonType
    let action: () -> Void

    enum ButtonType {
        case primary, secondary, outlined
    }

    init(_ title: String, icon: String? = nil, style: ButtonType = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.neueSubheadlineMedium)
                }
                Text(title)
                    .font(.neueSubheadlineMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(foregroundColor)
            .background(backgroundView)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                if style == .outlined {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AVIATheme.teal.opacity(0.3), lineWidth: 1.5)
                }
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: AVIATheme.teal
        case .outlined: AVIATheme.teal
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            AVIATheme.tealGradient
        case .secondary:
            AVIATheme.teal.opacity(0.1)
        case .outlined:
            Color.clear
        }
    }
}
