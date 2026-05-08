import SwiftUI

struct AdminTasksInboxView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var tasks: [ClientTask] = []
    @State private var isLoading: Bool = true
    @State private var filter: InboxFilter = .all

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

    private func clientName(for clientId: String) -> String {
        viewModel.allRegisteredUsers.first(where: { $0.id == clientId })?.fullName ?? "Client"
    }

    private func client(for id: String) -> ClientUser? {
        viewModel.allRegisteredUsers.first(where: { $0.id == id })
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
        .task { await load() }
        .refreshable { await load() }
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
