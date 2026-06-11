import Foundation

/// Robust ISO-8601 date handling for timestamps exchanged with Supabase.
///
/// Postgres returns `timestamptz` values both WITH fractional seconds
/// ("2026-06-11T05:23:45.123456+00:00") and WITHOUT them
/// ("2026-06-11T05:23:45+00:00"), while the app historically wrote
/// non-fractional strings. A parser configured only for fractional seconds
/// silently fails on half of these and every call site fell back to `.now`,
/// which broke message ordering, "time ago" labels and schedule sorting.
nonisolated enum SupabaseDate {
    /// Parses any common ISO-8601 / Postgres timestamp representation.
    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let candidates = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in candidates {
            df.dateFormat = format
            if let date = df.date(from: string) { return date }
        }
        return nil
    }

    /// Parses a timestamp, falling back to the provided default (default `.now`).
    static func parse(_ string: String?, default fallback: Date) -> Date {
        parse(string) ?? fallback
    }

    /// Serialises a date for Supabase with fractional-second precision so
    /// ordering between writes made in the same second stays stable.
    static func string(from date: Date) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.string(from: date)
    }
}
