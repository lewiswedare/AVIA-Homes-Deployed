import SwiftUI

struct AdminTasksInboxView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var tasks: [ClientTask] = []
    @State private var isLoading: Bool = true
    @State private var filter: InboxFilter = .all

    @State private var showAddTask: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskDetail: String = ""
    @State private var newTaskDue: Date = .now.addingTimeInterval(86400)
    @State private var newTaskPriority: TaskPriority = .normal
    @State private var newTaskHasDue: Bool = true
    @State private var newTaskClientId: String? = nil

    enum InboxFilter: String, CaseIterable, Identifiable {
        case all, mine, overdue, today, week
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All Open"
            case .mine: return "Mine"
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .week: return "This Week"
            }
        }
    }

    private var filtered: [ClientTask] {
        let me = viewModel.currentUser.id
        let cal = Calendar.current
        let now = Date()
        return tasks.filter { task in
            switch filter {
            case .all: return true
            case .mine: return task.assigneeId == me
            case .overdue: return task.isOverdue
            case .today:
                guard let due = task.dueAt else { return false }
                return cal.isDate(due, inSameDayAs: now)
            case .week:
                guard let due = task.dueAt else { return false }
                if let end = cal.date(byAdding: .day, value: 7, to: now) {
                    return due >= now && due <= end
                }
                return false
            }
        }
    }

    private func clientName(for clientId: String?) -> String {
        guard let clientId else { return "General task" }
        return viewModel.allRegisteredUsers.first(where: { $0.id == clientId })?.fullName ?? "Client"
    }

    private func client(for id: String?) -> ClientUser? {
        guard let id else { return nil }
        return viewModel.allRegisteredUsers.first(where: { $0.id == id })
    }

    private var clientOptions: [ClientUser] {
        let clients = viewModel.allRegisteredUsers.filter { $0.role == .client }
        return Array(Dictionary(grouping: clients, by: \.id).compactMap(\.value.first))
            .sorted { $0.lastName < $1.lastName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryStrip

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InboxFilter.allCases) { f in
                            Button {
                                filter = f
                            } label: {
                                Text(f.label)
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(filter == f ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background {
                                        if filter == f {
                                            AVIATheme.timelessBrown
                                        } else {
                                            AVIATheme.cardBackground
                                        }
                                    }
                                    .clipShape(.capsule)
                                    .overlay {
                                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: filter == f ? 0 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .contentMargins(.horizontal, 0)

                if isLoading && tasks.isEmpty {
                    ProgressView().padding(.vertical, 40)
                } else if filtered.isEmpty {
                    AdminEmptyState(
                        icon: "checklist",
                        title: "All caught up",
                        subtitle: "No tasks match this filter."
                    )
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 8) {
                        ForEach(filtered) { task in
                            if let c = client(for: task.clientId) {
                                NavigationLink(value: c) {
                                    taskRow(task)
                                }
                                .buttonStyle(.plain)
                            } else {
                                taskRow(task)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 14)
        }
        .background(AVIATheme.background)
        .navigationTitle("Tasks Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    resetNewTask()
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTask) { addTaskSheet }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Add task

    private func resetNewTask() {
        newTaskTitle = ""
        newTaskDetail = ""
        newTaskDue = .now.addingTimeInterval(86400)
        newTaskPriority = .normal
        newTaskHasDue = true
        newTaskClientId = nil
    }

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $newTaskTitle)
                    TextField("Details (optional)", text: $newTaskDetail, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Link to client") {
                    Picker("Client", selection: $newTaskClientId) {
                        Text("General (no client)").tag(String?.none)
                        ForEach(clientOptions) { c in
                            Text(c.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? c.email : c.fullName)
                                .tag(String?.some(c.id))
                        }
                    }
                }
                Section("Schedule") {
                    Toggle("Has due date", isOn: $newTaskHasDue)
                    if newTaskHasDue {
                        DatePicker("Due", selection: $newTaskDue)
                    }
                    Picker("Priority", selection: $newTaskPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTask = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNewTask() }
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveNewTask() {
        let task = ClientTask(
            id: UUID().uuidString,
            clientId: newTaskClientId,
            title: newTaskTitle.trimmingCharacters(in: .whitespaces),
            detail: newTaskDetail.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newTaskDetail,
            dueAt: newTaskHasDue ? newTaskDue : nil,
            completedAt: nil,
            assigneeId: viewModel.currentUser.id,
            createdBy: viewModel.currentUser.id,
            priority: newTaskPriority,
            createdAt: .now
        )
        tasks.insert(task, at: 0)
        showAddTask = false
        Task { await SupabaseService.shared.upsertClientTask(task) }
    }

    private var summaryStrip: some View {
        let overdueCount = tasks.filter(\.isOverdue).count
        let mine = tasks.filter { $0.assigneeId == viewModel.currentUser.id }.count
        return HStack(spacing: 10) {
            AdminMetricCard(value: "\(tasks.count)", label: "Open", icon: "tray.fill", color: AVIATheme.timelessBrown)
            AdminMetricCard(value: "\(mine)", label: "Mine", icon: "person.fill", color: AVIATheme.success)
            AdminMetricCard(value: "\(overdueCount)", label: "Overdue", icon: "exclamationmark.triangle.fill", color: AVIATheme.warning)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
    }

    private func taskRow(_ task: ClientTask) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleComplete(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.neueTitle3)
                        .foregroundStyle(task.isCompleted ? AVIATheme.success : AVIATheme.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.neueCaption2)
                        Text(clientName(for: task.clientId))
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.textSecondary)
                    HStack(spacing: 8) {
                        if let due = task.dueAt {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar").font(.neueCaption2)
                                Text(due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.neueCaption2)
                            }
                            .foregroundStyle(task.isOverdue ? AVIATheme.warning : AVIATheme.textTertiary)
                        }
                        if task.isOverdue {
                            Text("OVERDUE")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.warning)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(12)
        }
    }

    private func toggleComplete(_ task: ClientTask) {
        var updated = task
        updated.completedAt = task.isCompleted ? nil : .now
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            if updated.isCompleted {
                tasks.remove(at: idx)
            } else {
                tasks[idx] = updated
            }
        }
        Task { await SupabaseService.shared.upsertClientTask(updated) }
    }

    private func load() async {
        isLoading = true
        tasks = await SupabaseService.shared.fetchAllOpenClientTasks()
        isLoading = false
    }
}
