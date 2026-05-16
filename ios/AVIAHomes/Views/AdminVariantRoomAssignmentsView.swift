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
    @State private var rows: [String: VariantRoomRowState] = [:] // keyed by room_id
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
        let (rms, all) = await (rmsTask, allTask)
        // This screen now only manages facade-agnostic assignments. Any
        // facade-scoped rows are owned by the dedicated facade-specific
        // products editor and are left untouched here.
        let mine = all.filter { $0.variant_id == variantId && $0.facade_id == nil }
        var state: [String: VariantRoomRowState] = [:]
        for assignment in mine {
            var row = state[assignment.room_id] ?? VariantRoomRowState(enabled: true)
            row.enabled = true
            var cell = VariantRoomCellState()
            cell.inclusion = assignment.inclusionValue
            cell.cost = assignment.cost > 0 ? String(format: "%.2f", assignment.cost) : ""
            cell.imageURL = assignment.image_url ?? ""
            row.perRange[assignment.range_id] = cell
            state[assignment.room_id] = row
        }
        rooms = rms
        rows = state
        isLoading = false
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let svc = SupabaseService.shared

        // Build the desired list of facade-agnostic assignments from the
        // editor state. For every enabled room we emit one row per range
        // (volos / messina / portobello) using the per-range cell values
        // entered by the admin (defaulting to Included / $0 / no image when
        // the admin left a range blank).
        var desired: [VariantRoomAssignmentInsert] = []
        for (roomId, state) in rows {
            guard state.enabled else { continue }
            for rangeId in rangeIds {
                let cell = state.perRange[rangeId] ?? VariantRoomCellState()
                let trimmedCost = cell.cost.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                let cost = Double(trimmedCost) ?? 0
                desired.append(
                    VariantRoomAssignmentInsert(
                        variant_id: variantId,
                        room_id: roomId,
                        range_id: rangeId,
                        facade_id: nil,
                        image_url: cell.imageURL.isEmpty ? nil : cell.imageURL,
                        cost: cost,
                        inclusion: cell.inclusion.rawValue,
                        sort_order: 0
                    )
                )
            }
        }

        // Replace strategy: wipe all facade-agnostic rows for this variant,
        // then bulk-insert the desired set. Far more reliable than per-row
        // upserts against the partial unique indexes (which Postgres treats
        // NULL-distinct). Facade-scoped rows are left untouched and managed
        // by the dedicated facade-specific products editor.
        let del = await svc.deleteFacadeAgnosticAssignments(variantId: variantId)
        guard del.ok else {
            errorMessage = "Couldn't clear old assignments: \(del.error ?? "unknown")"
            return
        }

        let ins = await svc.bulkInsertVariantRoomAssignments(desired)
        guard ins.ok else {
            errorMessage = "Save failed: \(ins.error ?? "unknown")"
            return
        }

        await CatalogDataManager.shared.loadAll()
        successMessage = "Room assignments saved"
        dismiss()
    }
}

struct VariantRoomCellState: Hashable {
    var inclusion: VariantInclusion = .included
    var cost: String = ""
    var imageURL: String = ""
}

struct VariantRoomRowState: Hashable {
    var enabled: Bool
    var perRange: [String: VariantRoomCellState] = [:]
}
