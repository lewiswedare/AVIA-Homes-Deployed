import Foundation
import Testing
@testable import AVIAHomes

/// Tests for the shared Supabase timestamp parser — the single most
/// load-bearing utility in the app: message ordering, "time ago" labels and
/// schedule sorting all depend on it handling every Postgres timestamp shape.
struct SupabaseDateTests {
    @Test func parsesFractionalSecondsTimestamp() {
        let date = SupabaseDate.parse("2026-06-11T05:23:45.123456+00:00")
        #expect(date != nil)
    }

    @Test func parsesNonFractionalTimestamp() {
        let date = SupabaseDate.parse("2026-06-11T05:23:45+00:00")
        #expect(date != nil)
    }

    @Test func parsesSpaceSeparatedTimestamp() {
        let date = SupabaseDate.parse("2026-06-11 05:23:45+00:00")
        #expect(date != nil)
    }

    @Test func parsesDateOnly() {
        let date = SupabaseDate.parse("2026-06-11")
        #expect(date != nil)
    }

    @Test func fractionalAndNonFractionalAgreeOnInstant() {
        let a = SupabaseDate.parse("2026-06-11T05:23:45.000+00:00")
        let b = SupabaseDate.parse("2026-06-11T05:23:45+00:00")
        #expect(a == b)
    }

    @Test func nilAndEmptyReturnNil() {
        #expect(SupabaseDate.parse(nil) == nil)
        #expect(SupabaseDate.parse("") == nil)
        #expect(SupabaseDate.parse("not a date") == nil)
    }

    @Test func fallbackDefaultIsUsed() {
        let fallback = Date(timeIntervalSince1970: 0)
        #expect(SupabaseDate.parse("garbage", default: fallback) == fallback)
    }

    @Test func roundTripPreservesInstant() {
        let original = Date(timeIntervalSince1970: 1_781_200_000.5)
        let serialized = SupabaseDate.string(from: original)
        let parsed = SupabaseDate.parse(serialized)
        #expect(parsed != nil)
        if let parsed {
            #expect(abs(parsed.timeIntervalSince(original)) < 0.01)
        }
    }
}
