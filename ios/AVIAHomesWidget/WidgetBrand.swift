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

    static let success           = Color(red: 76/255,  green: 122/255, blue: 90/255)

    static let primaryGradient = LinearGradient(
        colors: [aviaBlack, timelessBrown],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Plain cream background, identical to AVIATheme.background.
    // The dashboard sits on flat cream, not a gradient.
    static let widgetBackdrop = aviaWhite
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
//   Mirrors:  Text("YOUR JOURNEY")
//             .font(.neueCaption2Medium).kerning(1).foregroundStyle(timelessBrown)

struct AVIAEyebrow: View {
    let text: String
    var size: CGFloat = 10
    var tint: Color = AVIAWidgetBrand.timelessBrown

    var body: some View {
        Text(text.uppercased())
            .font(.aviaCorpMedium(size))
            .kerning(1)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

// MARK: - Progress Ring (mirrors BuildJourneyCard.headerSection ring)
//   44pt circle, 4pt stroke, brown trim, sf-symbol icon centred

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

// MARK: - Stage Indicator (mirrors BuildJourneyCard.stageIndicator)
//   Filled brown for completed, brown-on-tint for current, grey for upcoming.
//   Connectors between dots: brown if completed, surfaceBorder otherwise.

struct AVIAStageIndicator: View {
    let total: Int
    let current: Int      // 0-based active index
    var dotSize: CGFloat = 14
    var fillSize: CGFloat = 6
    var connectorHeight: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                dot(at: i)
                if i < total - 1 {
                    Rectangle()
                        .fill(i < current ? AVIAWidgetBrand.timelessBrown : AVIAWidgetBrand.surfaceBorder)
                        .frame(height: connectorHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func dot(at i: Int) -> some View {
        ZStack {
            if i < current {
                Circle()
                    .fill(AVIAWidgetBrand.timelessBrown)
                    .frame(width: dotSize, height: dotSize)
                Image(systemName: "checkmark")
                    .font(.aviaCorpMedium(dotSize * 0.45))
                    .foregroundStyle(AVIAWidgetBrand.aviaWhite)
            } else if i == current {
                Circle()
                    .fill(AVIAWidgetBrand.timelessBrown.opacity(0.15))
                    .frame(width: dotSize, height: dotSize)
                Circle()
                    .fill(AVIAWidgetBrand.timelessBrown)
                    .frame(width: fillSize, height: fillSize)
            } else {
                Circle()
                    .fill(AVIAWidgetBrand.surfaceElevated)
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Bento Icon Circle (matches Theme.swift BentoIconCircle)

struct AVIABentoIcon: View {
    let icon: String
    var color: Color = AVIAWidgetBrand.timelessBrown
    var size: CGFloat = 36

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

// MARK: - Gradient action pill (mirrors BuildJourneyCard.actionButton)

struct AVIAActionPill: View {
    let title: String
    var icon: String = "arrow.right"
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.aviaCorpMedium(12))
            Image(systemName: icon)
                .font(.aviaCorpMedium(10))
        }
        .foregroundStyle(AVIAWidgetBrand.aviaWhite)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(AVIAWidgetBrand.primaryGradient)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Task row (mirrors BuildJourneyCard.tasksList)

struct AVIATaskRow: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.aviaCorp(11))
                .foregroundStyle(isComplete ? AVIAWidgetBrand.success : AVIAWidgetBrand.textTertiary)
            Text(title)
                .font(.aviaCorp(11))
                .foregroundStyle(isComplete ? AVIAWidgetBrand.textSecondary : AVIAWidgetBrand.textPrimary)
                .strikethrough(isComplete, color: AVIAWidgetBrand.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
