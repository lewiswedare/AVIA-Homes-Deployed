import SwiftUI

/// User-controllable zoom for the main content area when the app runs on macOS
/// (Mac Catalyst). It lets users scale the screens up or down — like browser
/// zoom — while the sidebar navigation stays at its native size. No effect on
/// iPhone or iPad, where the adaptive layout already handles sizing.
@Observable
final class MacZoom {
    static let minScale: CGFloat = 0.8
    static let maxScale: CGFloat = 2.0
    static let step: CGFloat = 0.1

    private static let storageKey = "macContentZoom"

    /// Current content scale. `1.0` is actual size.
    var scale: CGFloat {
        didSet { UserDefaults.standard.set(Double(scale), forKey: Self.storageKey) }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.storageKey)
        scale = stored > 0 ? CGFloat(stored) : 1.0
    }

    var percent: Int { Int((scale * 100).rounded()) }
    var canZoomIn: Bool { scale < Self.maxScale - 0.001 }
    var canZoomOut: Bool { scale > Self.minScale + 0.001 }
    var isActualSize: Bool { abs(scale - 1.0) < 0.001 }

    func zoomIn() { setScale(scale + Self.step) }
    func zoomOut() { setScale(scale - Self.step) }
    func reset() { setScale(1.0) }

    private func setScale(_ value: CGFloat) {
        let clamped = min(max(value, Self.minScale), Self.maxScale)
        // Snap to the nearest 0.1 so the displayed percentage stays tidy.
        scale = (clamped * 10).rounded() / 10
    }
}

extension View {
    /// Scales this view on Mac Catalyst according to the shared `MacZoom` level,
    /// reflowing the layout to the zoomed size (like browser zoom) so inner
    /// scroll views keep working. No-op on iPhone and iPad.
    ///
    /// Apply this to a tab's content root — never to the `TabView` itself — so
    /// the adaptive sidebar stays at its native size while the content zooms.
    func macZoomableContent() -> some View {
        modifier(MacZoomableContent())
    }
}

private struct MacZoomableContent: ViewModifier {
    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        MacZoomLayer { content }
        #else
        content
        #endif
    }
}

#if targetEnvironment(macCatalyst)
private struct MacZoomLayer<Content: View>: View {
    @Environment(MacZoom.self) private var macZoom
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Lay the content out in a logical area sized to `available / zoom`,
        // then scale it back up to fill the real area. Zooming in shrinks the
        // logical space (bigger UI, less visible); zooming out does the reverse.
        let zoom = max(macZoom.scale, 0.1)
        GeometryReader { proxy in
            content()
                .frame(width: proxy.size.width / zoom, height: proxy.size.height / zoom)
                .scaleEffect(zoom, anchor: .topLeading)
        }
    }
}
#endif
