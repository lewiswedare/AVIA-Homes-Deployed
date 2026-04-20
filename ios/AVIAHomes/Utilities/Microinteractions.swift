import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptic Manager
//
// Thin wrapper around UIFeedbackGenerator so we have a single pre-prepared
// source of truth for haptic feedback. Pre-preparing generators gives a more
// responsive feel — the Taptic Engine is already warmed up when the touch
// actually fires.

enum AVIAHaptic {
    case lightTap          // subtle press confirmations
    case mediumTap         // primary CTA presses, filter toggles
    case heavyTap          // major state changes (rare — reserved for signing, submitting)
    case selection         // picker / segmented control style feedback
    case success           // positive completion (EOI submitted, contract confirmed, build created)
    case warning           // soft negative (declined package)
    case error             // failure (save failed, network error)

    func trigger() {
        #if canImport(UIKit)
        switch self {
        case .lightTap:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred()
        case .mediumTap:
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.prepare()
            g.impactOccurred()
        case .heavyTap:
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.prepare()
            g.impactOccurred()
        case .selection:
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        case .success:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        case .warning:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.warning)
        case .error:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.error)
        }
        #endif
    }
}

// MARK: - Pressable Button Style
//
// Uniform press microinteraction for all tappable controls:
//   - subtle spring scale to 0.97 while pressed
//   - brightness dip so pressed state is visually obvious on darker CTAs
//   - haptic fires on press-down (not on release) so it feels instantly
//     responsive, matching the iOS system behavior for stock buttons.

struct PressableButtonStyle: ButtonStyle {
    enum Intensity {
        case subtle       // scale only, no haptic — for tiles, cards, ghost buttons
        case standard     // scale + light impact — default
        case prominent    // scale + medium impact — primary CTAs
    }

    var intensity: Intensity = .standard
    var pressScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.7),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, intensity != .subtle else { return }
                switch intensity {
                case .subtle: break
                case .standard: AVIAHaptic.lightTap.trigger()
                case .prominent: AVIAHaptic.mediumTap.trigger()
                }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(_ intensity: PressableButtonStyle.Intensity, scale: CGFloat = 0.97) -> PressableButtonStyle {
        PressableButtonStyle(intensity: intensity, pressScale: scale)
    }
}

// MARK: - Tap Bounce Modifier
//
// For elements that should visually react to a tap but are not SwiftUI Buttons
// (e.g. nav tiles wrapped in NavigationLink, Text that triggers a sheet via
// onTapGesture). Applies a quick scale pulse and a light haptic.

struct TapBounceModifier: ViewModifier {
    @State private var scale: CGFloat = 1
    var haptic: AVIAHaptic = .lightTap
    var action: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: scale)
            .onTapGesture {
                haptic.trigger()
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    scale = 0.96
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                        scale = 1
                    }
                }
                action?()
            }
    }
}

extension View {
    /// Tap-to-bounce microinteraction for non-Button tappables.
    /// If `action` is nil, only the visual/haptic feedback fires (useful when
    /// a `NavigationLink` or sheet binding handles the navigation itself).
    func tapBounce(haptic: AVIAHaptic = .lightTap, perform action: (() -> Void)? = nil) -> some View {
        modifier(TapBounceModifier(haptic: haptic, action: action))
    }

    /// Fire a haptic at a well-defined moment (e.g. after a save returns success).
    /// Prefer this over UIKit calls scattered across views.
    func haptic(_ kind: AVIAHaptic, trigger: some Equatable) -> some View {
        self.sensoryFeedback(kind.sensoryFeedback, trigger: trigger)
    }
}

// MARK: - SensoryFeedback Bridge

extension AVIAHaptic {
    /// Mapping to SwiftUI's built-in SensoryFeedback so callers can use
    /// `.sensoryFeedback(...)` with the same vocabulary.
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .lightTap: return .impact(weight: .light)
        case .mediumTap: return .impact(weight: .medium)
        case .heavyTap: return .impact(weight: .heavy)
        case .selection: return .selection
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
}

// MARK: - Haptic Pull-To-Refresh
//
// Wraps `.refreshable` so every refresh surface in the app gets the same
// "begin" + "complete" feedback without each callsite having to remember.

extension View {
    /// Pull-to-refresh that emits a light impact on begin and a success
    /// notification on completion (or an error haptic if the action throws).
    /// Drop-in replacement for `.refreshable`.
    func hapticRefresh(action: @MainActor @Sendable @escaping () async -> Void) -> some View {
        self.refreshable {
            await MainActor.run { AVIAHaptic.lightTap.trigger() }
            await action()
            await MainActor.run { AVIAHaptic.success.trigger() }
        }
    }
}

// MARK: - Shimmer (used for loading placeholders)
//
// Lightweight shimmer modifier. Adds a moving highlight across the view to
// signal "content loading" rather than showing a static skeleton. Opt-in:
// call `.shimmer(active: isLoading)` on a shape or placeholder view.

struct ShimmerModifier: ViewModifier {
    var active: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(20))
                        .offset(x: phase * geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
            }
    }
}

extension View {
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}
