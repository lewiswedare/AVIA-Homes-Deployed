import SwiftUI

// Brand styling for the AVIA Homes widget.
// Mirrors AVIATheme + PP Neue Corp from the main app so the widget feels native.

enum AVIAWidgetBrand {
    // Palette — mirror AVIATheme exactly.
    static let aviaBlack      = Color(red: 26/255,  green: 26/255,  blue: 26/255)
    static let aviaWhite      = Color(red: 225/255, green: 221/255, blue: 220/255)
    static let timelessBrown  = Color(red: 55/255,  green: 51/255,  blue: 43/255)
    static let heritageBlue   = Color(red: 142/255, green: 155/255, blue: 146/255)
    static let cardCream      = Color(red: 235/255, green: 232/255, blue: 231/255)
    static let cardCreamAlt   = Color(red: 242/255, green: 240/255, blue: 239/255)
    static let surfaceBorder  = Color(red: 205/255, green: 201/255, blue: 199/255)

    // The warm AVIA backdrop the frosted glass sits over.
    // Cream → soft brown → black wash, with a hint of heritage blue. The blurred
    // orbs painted on top of this gradient give the glass something to refract.
    static let backdropGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 240/255, green: 235/255, blue: 230/255), location: 0.0),
            .init(color: Color(red: 215/255, green: 203/255, blue: 191/255), location: 0.45),
            .init(color: Color(red: 99/255,  green: 86/255,  blue: 73/255),  location: 0.85),
            .init(color: Color(red: 41/255,  green: 36/255,  blue: 30/255),  location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Soft luminous gradient used inside glass surfaces for the inner-light effect.
    static let glassSheen = LinearGradient(
        colors: [
            Color.white.opacity(0.42),
            Color.white.opacity(0.08),
            Color.white.opacity(0.18),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.55),
            Color.white.opacity(0.10),
            Color.white.opacity(0.35),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let progressFill = LinearGradient(
        colors: [aviaWhite, aviaWhite.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
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

// MARK: - Frosted glass surface

/// The signature widget surface — a translucent, soft-edged frosted glass
/// panel that picks up the warm AVIA backdrop sitting behind it.
struct AVIAGlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    // The blur layer — picks up the warm gradient + orbs behind it.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // A faint cream tint so the glass reads warm rather than cold.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AVIAWidgetBrand.aviaWhite.opacity(0.10))

                    // Inner sheen for the liquid-glass look.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AVIAWidgetBrand.glassSheen)
                        .blendMode(.plusLighter)
                        .opacity(0.55)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AVIAWidgetBrand.glassBorder, lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Backdrop

/// The warm gradient + soft blurred orbs that live behind the glass.
/// Without something visually rich behind it, the frosted material has
/// nothing to blur and just looks flat.
struct AVIAWarmBackdrop: View {
    var body: some View {
        ZStack {
            AVIAWidgetBrand.backdropGradient

            // Three softly blurred orbs that act as the "light" the glass refracts.
            Circle()
                .fill(Color(red: 248/255, green: 220/255, blue: 195/255).opacity(0.85))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -90, y: -110)

            Circle()
                .fill(AVIAWidgetBrand.heritageBlue.opacity(0.55))
                .frame(width: 180, height: 180)
                .blur(radius: 70)
                .offset(x: 110, y: 30)

            Circle()
                .fill(AVIAWidgetBrand.timelessBrown.opacity(0.45))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: 60, y: 140)

            // Very subtle warm wash on top so the orbs blend into the gradient.
            LinearGradient(
                colors: [Color.clear, AVIAWidgetBrand.timelessBrown.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Eyebrow label (uppercase tracked label used across the widget)

struct AVIAEyebrow: View {
    let text: String
    var icon: String? = nil
    var tint: Color = .white.opacity(0.75)

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(text.uppercased())
                .font(.aviaCorpMedium(9))
                .tracking(1.6)
        }
        .foregroundStyle(tint)
    }
}

// MARK: - Inline mini tile (bento atom)

struct AVIAGlassTile<Content: View>: View {
    var cornerRadius: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
            }
    }
}

// MARK: - Glass progress bar

struct AVIAGlassProgressBar: View {
    let value: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(AVIAWidgetBrand.progressFill)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
