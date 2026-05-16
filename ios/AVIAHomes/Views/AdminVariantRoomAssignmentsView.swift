import SwiftUI

// MARK: - Variant Room Assignments
//
// For one variant (a row in spec_product_colours), edit per-room, per-range
// inclusion + cost + image. This is the heart of the room-first restructure:
// admins assign each variant to one or more rooms with the room-specific image
// and cost that the client will see when shopping that room.

struct AdminVariantRoomAssignmentsView: View {
    let variantId: String
    let variantName: String

    @Environment(\.dismiss) private var dismiss
    @State private var rooms: [SpecCategoryRow] = []
    @State private var facades: [Facade] = []
    @State private var rows: [String: VariantRoomRowState] = [:] // keyed by room_id
    /// Tracks the (room_id, facade_id) keys of the assignments that existed
    /// when we loaded, so we can detect deletes for facade-scoped rows that
    /// the admin has unscoped or removed.
    @State private var existingAssignmentKeys: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard

                    if isLoading {
                        ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                    } else if rooms.isEmpty {
                        AdminEmptyState(
                            icon: "square.grid.2x2",
                            title: "No Rooms",
                            subtitle: "Add rooms first under Catalog → Rooms."
                        )
                    } else {
                        ForEach(rooms.sorted { $0.sort_order < $1.sort_order }, id: \.id) { room in
                            roomCard(room)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Room Assignments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(AVIATheme.timelessBrown)
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
            .overlay(alignment: .bottom) { toastOverlay }
            .task { await load() }
        }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: "house.lodge.fill")
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.heritageBlue)
                    .frame(width: 40, height: 40)
                    .background(AVIATheme.heritageBlue.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(variantName.isEmpty ? "Variant" : variantName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Enable the rooms this variant belongs to, then set image + cost + inclusion per range.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private func roomCard(_ room: SpecCategoryRow) -> some View {
        let isOn = rows[room.id]?.enabled ?? false
        return BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: room.icon)
                        .font(.neueCorp(14))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(width: 36, height: 36)
                        .background(AVIATheme.timelessBrown.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 8))
                    Text(room.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { rows[room.id]?.enabled ?? false },
                        set: { newValue in
                            var state = rows[room.id] ?? VariantRoomRowState(enabled: false)
                            state.enabled = newValue
                            rows[room.id] = state
                        }
                    ))
                    .labelsHidden()
                    .tint(AVIATheme.heritageBlue)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                if isOn {
                    facadePicker(roomId: room.id)
                        .padding(.horizontal, 14)
                    ForEach(rangeIds, id: \.self) { rangeId in
                        rangeBlock(roomId: room.id, rangeId: rangeId)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                } else {
                    Text("Not assigned to this room")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func facadePicker(roomId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.neueCorp(11))
                    .foregroundStyle(AVIATheme.heritageBlue)
                Text("Facade scope")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }
            Picker("", selection: Binding(
                get: { rows[roomId]?.facadeId ?? "" },
                set: { newValue in
                    var state = rows[roomId] ?? VariantRoomRowState(enabled: true)
                    state.facadeId = newValue.isEmpty ? nil : newValue
                    rows[roomId] = state
                }
            )) {
                Text("All facades").tag("")
                ForEach(facades, id: \.id) { facade in
                    Text(facade.name).tag(facade.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AVIATheme.timelessBrown)
            Text("Pick a facade to only surface this variant when the build uses that facade. Leave on “All facades” for the default behaviour.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(10)
        .background(AVIATheme.heritageBlue.opacity(0.06))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func rangeBlock(roomId: String, rangeId: String) -> some View {
        let color = rangeColors[rangeId] ?? AVIATheme.timelessBrown
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(rangeNames[rangeId] ?? rangeId)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            Picker("", selection: Binding(
                get: { rows[roomId]?.perRange[rangeId]?.inclusion ?? .included },
                set: { newValue in
                    var state = rows[roomId] ?? VariantRoomRowState(enabled: true)
                    var perRange = state.perRange[rangeId] ?? VariantRoomCellState()
                    perRange.inclusion = newValue
                    state.perRange[rangeId] = perRange
                    rows[roomId] = state
                }
            )) {
                ForEach(VariantInclusion.allCases, id: \.self) { inc in
                    Text(inc.displayName).tag(inc)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Text("Cost").font(.neueCaption2).foregroundStyle(AVIATheme.textSecondary)
                Spacer()
                Text("$").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                TextField("0.00", text: Binding(
                    get: { rows[roomId]?.perRange[rangeId]?.cost ?? "" },
                    set: { newValue in
                        var state = rows[roomId] ?? VariantRoomRowState(enabled: true)
                        var perRange = state.perRange[rangeId] ?? VariantRoomCellState()
                        perRange.cost = newValue
                        state.perRange[rangeId] = perRange
                        rows[roomId] = state
                    }
                ))
                .font(.neueCaption)
                .keyboardType(.decimalPad)
                .frame(width: 100)
                .padding(8)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))
                Text("AUD").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Image for \(rangeNames[rangeId] ?? rangeId) in this room")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                AdminCompactImagePicker(
                    imageURL: Binding(
                        get: { rows[roomId]?.perRange[rangeId]?.imageURL ?? "" },
                        set: { newValue in
                            var state = rows[roomId] ?? VariantRoomRowState(enabled: true)
                            var perRange = state.perRange[rangeId] ?? VariantRoomCellState()
                            perRange.imageURL = newValue
                            state.perRange[rangeId] = perRange
                            rows[roomId] = state
                        }
                    ),
                    folder: "variant-room-assignments/\(rangeId)",
                    itemId: "\(variantId)_\(roomId)_\(rangeId)"
                )
            }
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.success, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { successMessage = nil }
                    }
                }
        }
        if let msg = errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { errorMessage = nil }
                    }
                }
        }
    }

    private func load() async {
        isLoading = true
        async let rmsTask = SupabaseService.shared.fetchSpecCategoryRowsPublic()
        async let allTask = SupabaseService.shared.fetchVariantRoomAssignments()
        async let facadesTask = SupabaseService.shared.fetchFacades()
        let (rms, all, fcs) = await (rmsTask, allTask, facadesTask)
        let mine = all.filter { $0.variant_id == variantId }
        var state: [String: VariantRoomRowState] = [:]
        var keys: Set<String> = []
        for assignment in mine {
            var row = state[assignment.room_id] ?? VariantRoomRowState(enabled: true)
            row.enabled = true
            // The admin UI surfaces a single facade scope per room. If the
            // variant has multiple facade-scoped rows we display the first
            // one and rely on duplicate variants to express the rest.
            if row.facadeId == nil { row.facadeId = assignment.facade_id }
            var cell = VariantRoomCellState()
            cell.inclusion = assignment.inclusionValue
            cell.cost = assignment.cost > 0 ? String(format: "%.2f", assignment.cost) : ""
            cell.imageURL = assignment.image_url ?? ""
            row.perRange[assignment.range_id] = cell
            state[assignment.room_id] = row
            keys.insert("\(assignment.room_id)|\(assignment.range_id)|\(assignment.facade_id ?? "-")")
        }
        rooms = rms
        facades = fcs
        rows = state
        existingAssignmentKeys = keys
        isLoading = false
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let svc = SupabaseService.shared
        var failures = 0

        // Fetch existing to delete rows that are no longer present.
        let existing = await svc.fetchVariantRoomAssignments()
        let mineExisting = existing.filter { $0.variant_id == variantId }

        // Build target set of (room, range, facade) we will keep.
        var keep: Set<String> = []
        for (roomId, state) in rows {
            guard state.enabled else { continue }
            for rangeId in rangeIds {
                let cell = state.perRange[rangeId] ?? VariantRoomCellState()
                let trimmedCost = cell.cost.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                let cost = Double(trimmedCost) ?? 0
                let row = VariantRoomAssignmentRow(
                    id: nil,
                    variant_id: variantId,
                    room_id: roomId,
                    range_id: rangeId,
                    facade_id: state.facadeId,
                    image_url: cell.imageURL.isEmpty ? nil : cell.imageURL,
                    cost: cost,
                    inclusion: cell.inclusion.rawValue,
                    sort_order: 0
                )
                if !(await svc.upsertVariantRoomAssignment(row)) { failures += 1 }
                keep.insert("\(roomId)|\(rangeId)|\(state.facadeId ?? "-")")
            }
        }

        for existingRow in mineExisting {
            let key = "\(existingRow.room_id)|\(existingRow.range_id)|\(existingRow.facade_id ?? "-")"
            if !keep.contains(key) {
                _ = await svc.deleteVariantRoomAssignment(
                    variantId: existingRow.variant_id,
                    roomId: existingRow.room_id,
                    rangeId: existingRow.range_id,
                    facadeId: existingRow.facade_id
                )
            }
        }

        await CatalogDataManager.shared.loadAll()
        if failures == 0 {
            successMessage = "Room assignments saved"
            dismiss()
        } else {
            errorMessage = "Some assignments failed (\(failures))"
        }
    }
}

struct VariantRoomCellState: Hashable {
    var inclusion: VariantInclusion = .included
    var cost: String = ""
    var imageURL: String = ""
}

struct VariantRoomRowState: Hashable {
    var enabled: Bool
    /// Optional facade scope for this room's assignments. `nil` = applies to
    /// every facade (default).
    var facadeId: String? = nil
    var perRange: [String: VariantRoomCellState] = [:]
}
