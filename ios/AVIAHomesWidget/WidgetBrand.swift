import SwiftUI

// Brand styling for the AVIA Homes widget.
// Mirrors AVIATheme + PP Neue Corp from the main app so the widget
// reads like a mini dashboard pulled straight out of the app.

enum AVIAWidgetBrand {
    // Palette — kept in sync with AVIATheme in the main app.
    static let aviaBlack         = Color(red: 26/255,  green: 26/255,  blue: 26/255)
    static let aviaWhite         = Color(red: 225/255, green: 221/255, blue: 220/255)
    static let timelessBrown     = Color(red: 55/255,  green: 51/255,  blue: 43/255)
    static let heritageBlue      = Color(red: 142/255, green: 155/255, blue: 146/255)

    static let background        = aviaWhite
    static let cardBackground    = Color(red: 235/255, green: 232/255, blue: 231/255)
    static let cardBackgroundAlt = Color(red: 242/255, green: 240/255, blue: 239/255)
    static let surfaceElevated   = Color(red: 216/255, green: 212/255, blue: 211/255)
    static let surfaceBorder     = Color(red: 205/255, green: 201/255, blue: 199/255)

    static let textPrimary       = aviaBlack
    static let textSecondary     = aviaBlack.opacity(0.55)
    static let textTertiary      = aviaBlack.opacity(0.35)

    static let primaryGradient = LinearGradient(
        colors: [aviaBlack, timelessBrown],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Gentle cream-to-warm wash used as the widget container background.
    // Same vibe as DashboardView — never dark.
    static let widgetBackdrop = LinearGradient(
        stops: [
            .init(color: Color(red: 232/255, green: 228/255, blue: 226/255), location: 0.0),
            .init(color: aviaWhite,                                              location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Fonts

extension Font {
    static func aviaCorp(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalRegular", size: size)
    }
    static func aviaCorpMedium(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalMedium", size: size)
    }
    static func aviaCorpUltralight(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalUltralight", size: size)
    }
}

// MARK: - Bento Card (in-app cream card, mirrors BentoCard in Theme.swift)

struct AVIABentoCard<Content: View>: View {
    var cornerRadius: CGFloat = 13
    var background: Color = AVIAWidgetBrand.cardBackground
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Eyebrow label (tracked caption used across the app)

struct AVIAEyebrow: View {
    let text: String
    var tint: Color = AVIAWidgetBrand.timelessBrown

    var body: some View {
        Text(text.uppercased())
            .font(.aviaCorpMedium(9))
            .kerning(1)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

// MARK: - Progress Ring (mirrors BuildJourneyCard's header ring)

struct AVIAProgressRing: View {
    let progress: Double
    let icon: String
    var diameter: CGFloat = 44
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(AVIAWidgetBrand.timelessBrown.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    AVIAWidgetBrand.timelessBrown,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: icon)
                .font(.aviaCorpMedium(diameter * 0.36))
                .foregroundStyle(AVIAWidgetBrand.timelessBrown)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Step Indicator (compact horizontal dots)

struct AVIAStepIndicator: View {
    let total: Int
    let current: Int   // 0-based index of the active step

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(fill(for: i))
                    .frame(height: 4)
            }
        }
    }

    private func fill(for i: Int) -> Color {
        if i < current { return AVIAWidgetBrand.timelessBrown }
        if i == current { return AVIAWidgetBrand.timelessBrown.opacity(0.55) }
        return AVIAWidgetBrand.surfaceBorder
    }
}

// MARK: - Bento Icon Circle (matches Theme.swift BentoIconCircle)

struct AVIABentoIcon: View {
    let icon: String
    var color: Color = AVIAWidgetBrand.timelessBrown
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: icon)
            .font(.aviaCorpMedium(size * 0.42))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }
}

// MARK: - AVIA wordmark (template-rendered like in DashboardView)

struct AVIAWordmark: View {
    var height: CGFloat = 18
    var tint: Color = AVIAWidgetBrand.timelessBrown

    var body: some View {
        Image("AVIALogo")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .foregroundStyle(tint)
    }
}
