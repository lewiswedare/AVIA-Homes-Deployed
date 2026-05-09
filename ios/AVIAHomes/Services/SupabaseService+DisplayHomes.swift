import Foundation
import Supabase

// Display-Home CRUD + realtime extracted to a separate file so the main
// SupabaseService stays manageable.
extension SupabaseService {
    // MARK: - Listings

    func fetchDisplayHomes(includeInactive: Bool = false) async -> [DisplayHome] {
        guard isConfigured else { return [] }
        do {
            var query = client.from("display_homes").select()
            if !includeInactive {
                query = query.eq("is_active", value: true)
            }
            let rows: [DisplayHomeRow] = try await query
                .order("sort_order", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value
            return rows.map { $0.toDisplayHome() }
        } catch {
            print("[SupabaseService] fetchDisplayHomes FAILED: \(error)")
            return []
        }
    }

    @discardableResult
    func upsertDisplayHome(_ home: DisplayHome) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("display_homes")
                .upsert(DisplayHomeRow(from: home))
                .execute()
            return true
        } catch {
            print("[SupabaseService] upsertDisplayHome FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteDisplayHome(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("display_homes").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteDisplayHome FAILED: \(error)")
            return false
        }
    }

    // MARK: - Visits

    func fetchDisplayHomeVisits() async -> [DisplayHomeVisit] {
        guard isConfigured else { return [] }
        do {
            let rows: [DisplayHomeVisitRow] = try await client
                .from("display_home_visits")
                .select()
                .order("requested_at", ascending: true)
                .execute()
                .value
            return rows.map { $0.toVisit() }
        } catch {
            print("[SupabaseService] fetchDisplayHomeVisits FAILED: \(error)")
            return []
        }
    }

    func fetchDisplayHomeVisits(forClient clientId: String) async -> [DisplayHomeVisit] {
        guard isConfigured, !clientId.isEmpty else { return [] }
        do {
            let rows: [DisplayHomeVisitRow] = try await client
                .from("display_home_visits")
                .select()
                .eq("client_id", value: clientId)
                .order("requested_at", ascending: false)
                .execute()
                .value
            return rows.map { $0.toVisit() }
        } catch {
            print("[SupabaseService] fetchDisplayHomeVisits(client) FAILED: \(error)")
            return []
        }
    }

    @discardableResult
    func upsertDisplayHomeVisit(_ visit: DisplayHomeVisit) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("display_home_visits")
                .upsert(DisplayHomeVisitRow(from: visit))
                .execute()
            return true
        } catch {
            print("[SupabaseService] upsertDisplayHomeVisit FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteDisplayHomeVisit(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("display_home_visits").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteDisplayHomeVisit FAILED: \(error)")
            return false
        }
    }

    // MARK: - Realtime

    func subscribeToDisplayHomeChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("display_homes_sync")
        realtimeChannels.append(channel)
        let listings = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "display_homes"
        )
        let visits = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "display_home_visits"
        )
        Task {
            try? await channel.subscribeWithError()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in listings {
                        await MainActor.run { onUpdate() }
                    }
                }
                group.addTask {
                    for await _ in visits {
                        await MainActor.run { onUpdate() }
                    }
                }
            }
        }
    }
}
