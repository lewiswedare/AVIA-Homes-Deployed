import SwiftUI

struct AdminBuildTimelineEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    let build: ClientBuild

    @State private var milestones: [BuildMilestone] = []
    @State private var reminders: [BuildReminder] = []
    @State private var isLoading = true
    @State private var showingAddMilestone = false
    @State private var showingAddReminder = false
    @State private var editingMilestone: BuildMilestone?
    @State private var selectedStageId: String = ""

    var body: some View {
        VStack(spacing: 16) {
            timelineOverviewCard
            milestonesSection
            remindersSection
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingAddMilestone) {
            AddMilestoneSheet(build: build, stageId: selectedStageId) { milestone in
                milestones.append(milestone)
                viewModel.addMilestone(milestone)
            }
        }
        .sheet(item: $editingMilestone) { milestone in
            EditMilestoneSheet(milestone: milestone) { updated in
                if let idx = milestones.firstIndex(where: { $0.id == updated.id }) {
                    milestones[idx] = updated
                }
                viewModel.updateMilestone(updated)
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet(build: build) { reminder in
                reminders.append(reminder)
                viewModel.addReminder(reminder)
            }
        }
    }

    private var timelineOverviewCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Timeline Overview", systemImage: "calendar.badge.clock")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(Int(build.overallProgress * 100))%")
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                if let start = build.estimatedStartDate {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Est. Start: \(start.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }

                if let end = build.estimatedCompletionDate {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(AVIATheme.success)
                        Text("Est. Completion: \(end.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }

                HStack(spacing: 16) {
                    statItem(label: "Stages", value: "\(build.buildStages.count)", color: AVIATheme.timelessBrown)
                    statItem(label: "Milestones", value: "\(milestones.count)", color: AVIATheme.warning)
                    statItem(label: "Reminders", value: "\(reminders.count)", color: AVIATheme.success)
                }
            }
            .padding(16)
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.neueCorpMedium(18))
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var milestonesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Milestones", systemImage: "flag.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Menu {
                    ForEach(build.buildStages) { stage in
                        Button(stage.name) {
                            selectedStageId = stage.id
                            showingAddMilestone = true
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if milestones.isEmpty {
                BentoCard(cornerRadius: 14) {
                    VStack(spacing: 10) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No milestones yet")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                        Text("Add milestones to track key events within each stage")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            } else {
                ForEach(groupedMilestonesByStage, id: \.stageId) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.stageName.uppercased())
                            .font(.neueCaption2Medium)
                            .kerning(0.5)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(.horizontal, 4)

                        ForEach(group.milestones) { milestone in
                            milestoneRow(milestone)
                        }
                    }
                }
            }
        }
    }

    private struct MilestoneGroup {
        let stageId: String
        let stageName: String
        let milestones: [BuildMilestone]
    }

    private var groupedMilestonesByStage: [MilestoneGroup] {
        let grouped = Dictionary(grouping: milestones, by: { $0.buildStageId })
        return build.buildStages.compactMap { stage in
            guard let items = grouped[stage.id], !items.isEmpty else { return nil }
            return MilestoneGroup(stageId: stage.id, stageName: stage.name, milestones: items)
        }
    }

    private func milestoneRow(_ milestone: BuildMilestone) -> some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Image(systemName: milestone.status == .completed ? "checkmark.circle.fill" : milestone.isOverdue ? "exclamationmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(milestone.status == .completed ? AVIATheme.success : milestone.isOverdue ? AVIATheme.destructive : AVIATheme.textTertiary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(milestone.title)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if milestone.requiresClientAction {
                            Text("ACTION")
                                .font(.neueCorpMedium(7))
                                .kerning(0.3)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AVIATheme.warning)
                                .clipShape(Capsule())
                        }
                    }
                    if let due = milestone.dueDate {
                        Text("Due: \(due.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.neueCaption2)
                            .foregroundStyle(milestone.isOverdue ? AVIATheme.destructive : AVIATheme.textTertiary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if milestone.status != .completed {
                        Button {
                            completeMilestoneAction(milestone)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.neueCorp(12))
                                .foregroundStyle(AVIATheme.success)
                        }
                    }

                    Button {
                        editingMilestone = milestone
                    } label: {
                        Image(systemName: "pencil")
                            .font(.neueCorp(12))
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }

                    Button {
                        deleteMilestoneAction(milestone)
                    } label: {
                        Image(systemName: "trash")
                            .font(.neueCorp(12))
                            .foregroundStyle(AVIATheme.destructive)
                    }
                }
            }
            .padding(14)
        }
    }

    private var remindersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Reminders", systemImage: "bell.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Button {
                    showingAddReminder = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            if reminders.isEmpty {
                BentoCard(cornerRadius: 14) {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No reminders set")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            } else {
                ForEach(reminders) { reminder in
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: reminder.isRead ? "bell.fill" : "bell.badge.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(reminder.isRead ? AVIATheme.textTertiary : AVIATheme.warning)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.title)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(reminder.message)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .lineLimit(2)
                                if let date = reminder.reminderDate {
                                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }

                            Spacer()

                            Button {
                                deleteReminderAction(reminder)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.neueCorp(12))
                                    .foregroundStyle(AVIATheme.destructive)
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        async let m = SupabaseService.shared.fetchMilestonesForBuild(buildId: build.id)
        async let r = SupabaseService.shared.fetchRemindersForBuild(buildId: build.id)
        milestones = await m
        reminders = await r
        isLoading = false
    }

    private func completeMilestoneAction(_ milestone: BuildMilestone) {
        withAnimation(.spring(response: 0.3)) {
            if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) {
                milestones[idx] = BuildMilestone(
                    id: milestone.id,
                    buildStageId: milestone.buildStageId,
                    buildId: milestone.buildId,
                    title: milestone.title,
                    description: milestone.description,
                    dueDate: milestone.dueDate,
                    completedAt: .now,
                    status: .completed,
                    requiresClientAction: milestone.requiresClientAction,
                    clientActionDescription: milestone.clientActionDescription,
                    createdAt: milestone.createdAt
                )
            }
        }
        viewModel.completeMilestone(id: milestone.id, buildId: build.id)
    }

    private func deleteMilestoneAction(_ milestone: BuildMilestone) {
        withAnimation(.spring(response: 0.3)) {
            milestones.removeAll { $0.id == milestone.id }
        }
        viewModel.deleteMilestone(id: milestone.id, buildId: build.id)
    }

    private func deleteReminderAction(_ reminder: BuildReminder) {
        withAnimation(.spring(response: 0.3)) {
            reminders.removeAll { $0.id == reminder.id }
        }
        viewModel.deleteReminder(id: reminder.id)
    }
}

// MARK: - Add Milestone Sheet

struct AddMilestoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild
    let stageId: String
    let onSave: (BuildMilestone) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date.now
    @State private var hasDueDate = true
    @State private var requiresClientAction = false
    @State private var clientActionDescription = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            field(label: "Title") {
                                TextField("e.g. Council Approval Received", text: $title)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Description") {
                                TextField("Details about this milestone", text: $description)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Due Date") {
                                Toggle("Set Due Date", isOn: $hasDueDate)
                                    .tint(AVIATheme.timelessBrown)
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(AVIATheme.timelessBrown)
                                }
                            }

                            field(label: "Client Action") {
                                Toggle("Requires Client Action", isOn: $requiresClientAction)
                                    .tint(AVIATheme.warning)
                                if requiresClientAction {
                                    TextField("What the client needs to do", text: $clientActionDescription)
                                        .font(.neueSubheadline)
                                }
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Add Milestone", icon: "flag.fill", style: .primary) {
                        let milestone = BuildMilestone(
                            id: UUID().uuidString,
                            buildStageId: stageId,
                            buildId: build.id,
                            title: title,
                            description: description,
                            dueDate: hasDueDate ? dueDate : nil,
                            completedAt: nil,
                            status: .pending,
                            requiresClientAction: requiresClientAction,
                            clientActionDescription: requiresClientAction ? clientActionDescription : nil,
                            createdAt: .now
                        )
                        onSave(milestone)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
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
}

// MARK: - Edit Milestone Sheet

struct EditMilestoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let milestone: BuildMilestone
    let onSave: (BuildMilestone) -> Void

    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var requiresClientAction: Bool
    @State private var clientActionDescription: String
    @State private var status: BuildMilestone.MilestoneStatus

    init(milestone: BuildMilestone, onSave: @escaping (BuildMilestone) -> Void) {
        self.milestone = milestone
        self.onSave = onSave
        _title = State(initialValue: milestone.title)
        _description = State(initialValue: milestone.description)
        _dueDate = State(initialValue: milestone.dueDate ?? .now)
        _hasDueDate = State(initialValue: milestone.dueDate != nil)
        _requiresClientAction = State(initialValue: milestone.requiresClientAction)
        _clientActionDescription = State(initialValue: milestone.clientActionDescription ?? "")
        _status = State(initialValue: milestone.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            field(label: "Title") {
                                TextField("Milestone title", text: $title)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Description") {
                                TextField("Details", text: $description)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Status") {
                                Picker("Status", selection: $status) {
                                    ForEach(BuildMilestone.MilestoneStatus.allCases, id: \.self) { s in
                                        Text(s.rawValue.capitalized).tag(s)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            field(label: "Due Date") {
                                Toggle("Set Due Date", isOn: $hasDueDate)
                                    .tint(AVIATheme.timelessBrown)
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(AVIATheme.timelessBrown)
                                }
                            }

                            field(label: "Client Action") {
                                Toggle("Requires Client Action", isOn: $requiresClientAction)
                                    .tint(AVIATheme.warning)
                                if requiresClientAction {
                                    TextField("What the client needs to do", text: $clientActionDescription)
                                        .font(.neueSubheadline)
                                }
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Save Changes", icon: "checkmark", style: .primary) {
                        let updated = BuildMilestone(
                            id: milestone.id,
                            buildStageId: milestone.buildStageId,
                            buildId: milestone.buildId,
                            title: title,
                            description: description,
                            dueDate: hasDueDate ? dueDate : nil,
                            completedAt: status == .completed ? (milestone.completedAt ?? .now) : nil,
                            status: status,
                            requiresClientAction: requiresClientAction,
                            clientActionDescription: requiresClientAction ? clientActionDescription : nil,
                            createdAt: milestone.createdAt
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
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
}

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild
    let onSave: (BuildReminder) -> Void

    @State private var title = ""
    @State private var message = ""
    @State private var reminderDate = Date.now
    @State private var selectedClientId: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            field(label: "Title") {
                                TextField("e.g. Colour Selection Due", text: $title)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Message") {
                                TextField("Reminder details", text: $message)
                                    .font(.neueSubheadline)
                            }

                            field(label: "Reminder Date") {
                                DatePicker("", selection: $reminderDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AVIATheme.timelessBrown)
                            }

                            if build.allClients.count > 1 {
                                field(label: "Client") {
                                    ForEach(build.allClients, id: \.id) { client in
                                        Button {
                                            selectedClientId = client.id
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text(client.fullName)
                                                    .font(.neueCaption)
                                                    .foregroundStyle(AVIATheme.textPrimary)
                                                Spacer()
                                                Image(systemName: selectedClientId == client.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedClientId == client.id ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Add Reminder", icon: "bell.fill", style: .primary) {
                        let clientId = selectedClientId.isEmpty ? build.client.id : selectedClientId
                        let reminder = BuildReminder(
                            id: UUID().uuidString,
                            buildId: build.id,
                            milestoneId: nil,
                            clientId: clientId,
                            title: title,
                            message: message,
                            reminderDate: reminderDate,
                            isRead: false,
                            createdAt: .now
                        )
                        onSave(reminder)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .onAppear {
            if selectedClientId.isEmpty {
                selectedClientId = build.client.id
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
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
}
