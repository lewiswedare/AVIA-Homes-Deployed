import SwiftUI

/// Global surface for background save failures.
///
/// Many admin actions save optimistically in a fire-and-forget `Task` (CRM
/// stage changes, notes, tasks, communication logs). When one of those writes
/// fails the data used to vanish silently — the UI showed success while the
/// server never stored it. Every background save now reports here, and a
/// dismissable banner appears at the app root.
@Observable
final class SaveErrorCenter {
    static let shared = SaveErrorCenter()

    /// The currently visible failure message, or nil when no banner shows.
    var message: String?

    private init() {}

    func report(_ message: String) {
        self.message = message
    }

    func dismiss() {
        message = nil
    }
}

/// Runs a background save and surfaces a banner when it fails.
///
/// Usage:
/// `backgroundSave("Couldn't save the note") { await SupabaseService.shared.upsertClientNote(note) }`
func backgroundSave(_ failureMessage: String, _ operation: @escaping () async -> Bool) {
    Task {
        let ok = await operation()
        if !ok {
            SaveErrorCenter.shared.report(failureMessage)
        }
    }
}

/// Top banner that shows the latest background-save failure. Attach once at
/// the app root via `.saveErrorBanner()`.
struct SaveErrorBannerModifier: ViewModifier {
    private let center = SaveErrorCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = center.message {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                        Text(message)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            center.dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                                .frame(width: 28, height: 28)
                        }
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AVIATheme.textPrimary)
                    .clipShape(.rect(cornerRadius: 13))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(6))
                        if center.message == message {
                            center.dismiss()
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.35), value: center.message)
    }
}

extension View {
    /// Shows background-save failure banners over this view.
    func saveErrorBanner() -> some View {
        modifier(SaveErrorBannerModifier())
    }
}
