import SwiftUI

struct AdminSpecRangeEditorView: View {
    @State private var tiers: [String: SpecRangeTierRow] = [:]
    @State private var isLoading = false
    @State private var editingTier: SpecTier?
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                if isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else {
                    VStack(spacing: 12) {
                        ForEach(SpecTier.allCases) { tier in
                            tierCard(tier: tier)
                        }
                    }
                }

                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Spec Ranges")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingTier) { tier in
            SpecRangeEditSheet(
                tier: tier,
                existing: tiers[tier.imageKeySuffix]
            ) { row in
                Task { await save(row: row) }
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await loadTiers() }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Spec Range Content")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Edit the hero image, summary, highlights and room gallery for each spec range")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func tierCard(tier: SpecTier) -> some View {
        let row = tiers[tier.imageKeySuffix]
        let highlightCount = row?.highlights.count ?? 0
        let roomCount = row?.room_images.count ?? 0
        let heroURL = row?.hero_image_url ?? ""

        return Button { editingTier = tier } label: {
            BentoCard(cornerRadius: 14) {
                VStack(spacing: 0) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(height: 150)
                        .overlay {
                            AsyncImage(url: URL(string: heroURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .overlay {
                            LinearGradient(
                                colors: [.clear, AVIATheme.aviaBlack.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.tagline.uppercased())
                                    .font(.neueCorpMedium(9))
                                    .kerning(1.0)
                                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.8))
                                Text(tier.displayName)
                                    .font(.neueCorpMedium(22))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                            }
                            .padding(12)
                        }
                        .clipShape(.rect(cornerRadii: .init(topLeading: 14, topTrailing: 14)))

                    HStack(spacing: 12) {
                        stat(icon: "text.alignleft", value: row?.summary.isEmpty == false ? "Summary set" : "No summary")
                        stat(icon: "star.fill", value: "\(highlightCount) highlights")
                        stat(icon: "photo.stack", value: "\(roomCount) rooms")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text(value)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textSecondary)
        }
    }

    private var infoCard: some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Changes sync instantly")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Updates to spec range content appear immediately on the Discover page for all users.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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

    private func loadTiers() async {
        isLoading = true
        tiers = await SupabaseService.shared.fetchSpecRangeTiers()
        isLoading = false
    }

    private func save(row: SpecRangeTierRow) async {
        let ok = await SupabaseService.shared.upsertSpecRangeTier(row)
        if ok {
            withAnimation { successMessage = "Spec range saved" }
            await loadTiers()
            await CatalogDataManager.shared.loadAll()
        } else {
            withAnimation { errorMessage = "Failed to save spec range" }
        }
    }
}

private struct SpecRangeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tier: SpecTier
    let existing: SpecRangeTierRow?
    let onSave: (SpecRangeTierRow) -> Void

    @State private var heroImageURL: String = ""
    @State private var summary: String = ""
    @State private var highlights: [EditableHighlight] = []
    @State private var roomImages: [EditableRoomImage] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    summaryCard
                    highlightsCard
                    roomsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit \(tier.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: populate)
        .presentationDetents([.large])
    }

    private var heroCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Hero Image")
                AdminImagePickerField(
                    label: "Hero Image",
                    imageURL: $heroImageURL,
                    folder: "spec-ranges",
                    itemId: "\(tier.rawValue)_hero"
                )
            }
            .padding(.vertical, 14)
        }
    }

    private var summaryCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Summary")
                sheetField("About This Range") {
                    TextField("Describe this spec range...", text: $summary, axis: .vertical)
                        .font(.neueCaption)
                        .lineLimit(4...12)
                }
            }
            .padding(.vertical, 14)
        }
    }

    private var highlightsCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader("Highlights")
                    Spacer()
                    Button {
                        withAnimation {
                            highlights.append(EditableHighlight(icon: "star.fill", title: "", subtitle: ""))
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    .padding(.trailing, 14)
                }

                if highlights.isEmpty {
                    Text("No highlights. Tap + to add one.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                } else {
                    ForEach(highlights) { hl in
                        highlightRow(hl)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func highlightRow(_ hl: EditableHighlight) -> some View {
        let binding = bindingForHighlight(hl.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Highlight")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
                Spacer()
                Button(role: .destructive) {
                    withAnimation { highlights.removeAll { $0.id == hl.id } }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(AVIATheme.destructive.opacity(0.7))
                }
            }

            sheetField("SF Symbol") {
                TextField("e.g. countertop.fill", text: binding.icon)
                    .font(.neueCaption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 0)

            sheetField("Title") {
                TextField("e.g. 20mm Stone Benchtops", text: binding.title)
                    .font(.neueCaption)
            }
            .padding(.horizontal, 0)

            sheetField("Subtitle") {
                TextField("Short description", text: binding.subtitle, axis: .vertical)
                    .font(.neueCaption)
                    .lineLimit(1...3)
            }
            .padding(.horizontal, 0)
        }
        .padding(12)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 14)
    }

    private var roomsCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader("Room Gallery")
                    Spacer()
                    Button {
                        withAnimation {
                            roomImages.append(EditableRoomImage(name: "", imageURL: ""))
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    .padding(.trailing, 14)
                }

                if roomImages.isEmpty {
                    Text("No room images. Tap + to add one.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                } else {
                    ForEach(roomImages) { room in
                        roomRow(room)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func roomRow(_ room: EditableRoomImage) -> some View {
        let binding = bindingForRoom(room.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Room")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
                Spacer()
                Button(role: .destructive) {
                    withAnimation { roomImages.removeAll { $0.id == room.id } }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(AVIATheme.destructive.opacity(0.7))
                }
            }

            sheetField("Room Name") {
                TextField("e.g. Kitchen", text: binding.name)
                    .font(.neueCaption)
            }
            .padding(.horizontal, 0)

            AdminImagePickerField(
                label: "Image",
                imageURL: binding.imageURL,
                folder: "spec-ranges/rooms",
                itemId: "\(tier.rawValue)_\(room.id.uuidString.prefix(8))"
            )
        }
        .padding(12)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 14)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func sheetField(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            field()
                .padding(10)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 8))
        }
        .padding(.horizontal, 14)
    }

    private func bindingForHighlight(_ id: UUID) -> (icon: Binding<String>, title: Binding<String>, subtitle: Binding<String>) {
        let idx = highlights.firstIndex(where: { $0.id == id }) ?? 0
        return (
            Binding(get: { highlights[idx].icon }, set: { highlights[idx].icon = $0 }),
            Binding(get: { highlights[idx].title }, set: { highlights[idx].title = $0 }),
            Binding(get: { highlights[idx].subtitle }, set: { highlights[idx].subtitle = $0 })
        )
    }

    private func bindingForRoom(_ id: UUID) -> (name: Binding<String>, imageURL: Binding<String>) {
        let idx = roomImages.firstIndex(where: { $0.id == id }) ?? 0
        return (
            Binding(get: { roomImages[idx].name }, set: { roomImages[idx].name = $0 }),
            Binding(get: { roomImages[idx].imageURL }, set: { roomImages[idx].imageURL = $0 })
        )
    }

    private func populate() {
        if let existing {
            heroImageURL = existing.hero_image_url
            summary = existing.summary
            highlights = existing.highlights.map {
                EditableHighlight(icon: $0.icon, title: $0.title, subtitle: $0.subtitle)
            }
            roomImages = existing.room_images.map {
                EditableRoomImage(name: $0.name, imageURL: $0.image_url)
            }
        } else {
            let seed = SpecRangeData.seedData(for: tier)
            heroImageURL = seed.heroImageURL
            summary = seed.summary
            highlights = seed.highlights.map {
                EditableHighlight(icon: $0.icon, title: $0.title, subtitle: $0.subtitle)
            }
            roomImages = SpecRangeData.roomImages(for: tier).map {
                EditableRoomImage(name: $0.name, imageURL: $0.imageURL)
            }
        }
    }

    private func save() {
        let row = SpecRangeTierRow(
            tier: tier.rawValue,
            hero_image_url: heroImageURL,
            summary: summary,
            highlights: highlights
                .filter { !$0.title.isEmpty }
                .map { SpecRangeTierRow.HighlightRow(icon: $0.icon, title: $0.title, subtitle: $0.subtitle) },
            room_images: roomImages
                .filter { !$0.name.isEmpty && !$0.imageURL.isEmpty }
                .map { SpecRangeTierRow.RoomImageRow(name: $0.name, image_url: $0.imageURL) }
        )
        onSave(row)
        dismiss()
    }
}

private struct EditableHighlight: Identifiable {
    let id = UUID()
    var icon: String
    var title: String
    var subtitle: String
}

private struct EditableRoomImage: Identifiable {
    let id = UUID()
    var name: String
    var imageURL: String
}
