import SwiftUI

/// Shared helpers that make every screen scale gracefully from iPhone up to iPad.
///
/// Strategy:
/// - Feed/list style content is constrained to a readable column and centered.
/// - Card collections widen into adaptive multi-column grids.
/// - Tab navigation switches to the adaptable sidebar style on iPad.
enum AdaptiveLayout {
    /// Readable width for feed-style content (tasks, conversations, settings).
    static let readableWidth: CGFloat = 720

    /// Wider cap for card grids and dashboards that benefit from more columns.
    static let wideWidth: CGFloat = 1060

    /// Width for workflow hubs that mix metric cards with feed rows.
    static let workspaceWidth: CGFloat = 860

    /// Grid columns that keep two columns on iPhone and grow on iPad.
    static func cardColumns(spacing: CGFloat = 12) -> [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 280), spacing: spacing)]
    }

    /// Grid columns that keep three columns on iPhone and grow on iPad.
    static func swatchColumns(spacing: CGFloat = 10) -> [GridItem] {
        [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: spacing)]
    }

    /// Denser columns that keep four columns on iPhone and grow on iPad.
    static func denseSwatchColumns(spacing: CGFloat = 10) -> [GridItem] {
        [GridItem(.adaptive(minimum: 76, maximum: 130), spacing: spacing)]
    }

    /// Columns for full-width feature cards: one column on iPhone, 2–3 on iPad.
    static func featureColumns(spacing: CGFloat = 12) -> [GridItem] {
        [GridItem(.adaptive(minimum: 320, maximum: 520), spacing: spacing)]
    }
}

extension View {
    /// Constrains content to a readable width on wide (iPad) layouts and centers it.
    /// On iPhone this is a no-op because the screen is narrower than the cap.
    func adaptiveContentWidth(_ maxWidth: CGFloat = AdaptiveLayout.readableWidth) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    /// Wide variant for dashboards and card grids.
    func adaptiveWideWidth() -> some View {
        adaptiveContentWidth(AdaptiveLayout.wideWidth)
    }
}
