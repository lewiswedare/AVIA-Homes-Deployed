import Foundation

/// Simple in-memory TTL cache for Supabase queries.
/// Mirrors the JS `cachedQuery(key, queryFn)` pattern with a 60-second default TTL.
///
/// Usage:
/// ```swift
/// let builds = try await SupabaseCache.shared.cachedQuery(key: "builds:\(userId)") {
///     try await supabase.client.from("builds").select("...").execute().value as [BuildRow]
/// }
/// ```
/// Use `invalidate(_:)` / `invalidate(prefix:)` after a write so the next read refetches.
actor SupabaseCache {
    static let shared = SupabaseCache()

    private struct Entry {
        let value: Any
        let timestamp: Date
    }

    private var store: [String: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 60) {
        self.ttl = ttl
    }

    func cachedQuery<T: Sendable>(
        key: String,
        ttlOverride: TimeInterval? = nil,
        _ queryFn: @Sendable () async throws -> T
    ) async throws -> T {
        let effectiveTTL = ttlOverride ?? ttl
        if let entry = store[key],
           Date().timeIntervalSince(entry.timestamp) < effectiveTTL,
           let value = entry.value as? T {
            return value
        }
        let value = try await queryFn()
        store[key] = Entry(value: value, timestamp: Date())
        return value
    }

    func invalidate(_ key: String) {
        store.removeValue(forKey: key)
    }

    func invalidate(prefix: String) {
        for k in store.keys where k.hasPrefix(prefix) {
            store.removeValue(forKey: k)
        }
    }

    func clear() {
        store.removeAll()
    }
}
