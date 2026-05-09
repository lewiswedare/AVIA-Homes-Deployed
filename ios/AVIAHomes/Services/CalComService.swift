import Foundation

/// Helper for building Cal.com booking links with prefilled client info.
///
/// The booking URL is configured via the `EXPO_PUBLIC_CALCOM_BOOKING_URL`
/// environment variable (e.g. `https://cal.com/avia-team/foundation-call`).
/// If unset, falls back to a sensible default that the team can replace.
enum CalComService {

    /// The configured base booking URL for the Foundation Call event type.
    static var bookingURL: String {
        let configured = (Config.allValues["EXPO_PUBLIC_CALCOM_BOOKING_URL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty { return configured }
        // Fallback — team can configure their real Cal.com link via env var.
        return "https://cal.com/avia/foundation-call"
    }

    /// Returns true if the link is configured (i.e. not the placeholder fallback).
    static var isConfigured: Bool {
        let configured = (Config.allValues["EXPO_PUBLIC_CALCOM_BOOKING_URL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !configured.isEmpty
    }

    /// Build a booking URL that prefills the attendee's name, email and notes.
    /// Cal.com supports `name`, `email`, and `notes` query params for prefill.
    static func bookingURL(name: String?, email: String?, notes: String? = nil, clientId: String? = nil) -> URL? {
        guard var components = URLComponents(string: bookingURL) else { return nil }
        var items = components.queryItems ?? []

        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if let email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let notes, !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "notes", value: notes))
        }
        if let clientId, !clientId.isEmpty {
            // Round-tripped via Cal.com metadata so the webhook can reconcile.
            items.append(URLQueryItem(name: "metadata[avia_client_id]", value: clientId))
        }

        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }
}
