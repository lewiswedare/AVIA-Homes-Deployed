import SwiftUI

struct AdminScheduleItemEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let clientId: String
    let existingItem: ScheduleItem?

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var date: Date = .now
    @State private var category: ScheduleItem.ItemType = .meeting
    @State private var isSaving = false

    private let categories: [ScheduleItem.ItemType] = [
        .meeting, .inspection, .siteVisit, .walkthrough, .colourDue, .handover
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 13) {
                        VStack(spacing: 14) {
                            field(label: "Title") {
                                TextField("e.g. Site Inspection", text: $title)
                                    .font(.neueSubheadline)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Description") {
                                TextField("Optional description", text: $subtitle)
                                    .font(.neueSubheadline)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Date & Time") {
                                DatePicker("", selection: $date)
                                    .labelsHidden()
                                    .tint(AVIATheme.timelessBrown)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Category") {
                                Picker("Category", selection: $category) {
                                    ForEach(categories, id: \.rawValue) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AVIATheme.timelessBrown)
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton(existingItem == nil ? "Add Milestone" : "Save Changes", icon: "checkmark", style: .primary) {
                        Task { await save() }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle(existingItem == nil ? "Add Milestone" : "Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .onAppear {
                if let item = existingItem {
                    title = item.title
                    subtitle = item.subtitle
                    date = item.date
                    category = item.type
                }
            }
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .kerning(0.5)
            content()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let item = ScheduleItem(
            id: existingItem?.id ?? UUID().uuidString,
            title: title,
            subtitle: subtitle,
            icon: category.rawValue,
            date: date,
            type: category
        )

        _ = await SupabaseService.shared.upsertScheduleItem(item, clientId: clientId)
        dismiss()
    }
}

struct AdminScheduleItemList: View {
    @Environment(AppViewModel.self) private var viewModel
    let clientId: String
    let items: [ScheduleItem]

    @State private var showAddSheet = false
    @State private var editingItem: ScheduleItem?
    @State private var showDeleteConfirm = false
    @State private var deletingItemId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIMELINE MILESTONES")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .kerning(0.5)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            if items.isEmpty {
                Text("No milestones yet")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    BentoCard(cornerRadius: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: item.iconColor)
                                .font(.neueCorpMedium(14))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 32, height: 32)
                                .background(AVIATheme.timelessBrown.opacity(0.1))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            StatusBadge(title: item.type.rawValue, color: AVIATheme.timelessBrown)
                        }
                        .padding(10)
                    }
                    .onTapGesture {
                        editingItem = item
                    }
                    .contextMenu {
                        Button("Edit") { editingItem = item }
                        Button("Delete", role: .destructive) {
                            deletingItemId = item.id
                            showDeleteConfirm = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AdminScheduleItemEditor(clientId: clientId, existingItem: nil)
        }
        .sheet(item: $editingItem) { item in
            AdminScheduleItemEditor(clientId: clientId, existingItem: item)
        }
        .alert("Delete Milestone?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = deletingItemId {
                    Task { _ = await SupabaseService.shared.deleteScheduleItem(id: id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

extension ScheduleItem: Hashable {
    nonisolated static func == (lhs: ScheduleItem, rhs: ScheduleItem) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
