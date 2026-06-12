import SwiftUI

/// The admin operating-system hub. Unifies the daily workflows — Today focus,
/// tasks, clients, jobs (builds), scheduling and documents/sending — into one
/// workflow-driven home screen with deep links into every existing detail screen.
struct AdminWorkspaceView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var lane: WorkflowLane = .today
    @State private var searchText: String = ""

    // Aggregated data
    @State private var tasks: [ClientTask] = []
    @State private var crmProfiles: [String: ClientCRMProfile] = [:]
    @State private var scheduleItems: [(clientId: String, item: ScheduleItem)] = []
    @State private var isLoading: Bool = true

    // Sheets / quick actions
    @State private var showingAddBuild: Bool = false
    @State private var showAddTask: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskDetail: String = ""
    @State private var newTaskDue: Date = .now.addingTimeInterval(86400)
    @State private var newTaskPriority: TaskPriority = .normal
    @State private var newTaskHasDue: Bool = true
    @State private var newTaskClientId: String? = nil

    enum WorkflowLane: String, CaseIterable, Identifiable {
        case today, tasks, leads, clients, jobs, schedule, sending
        var id: String { rawValue }
        var label: String {
            switch self {
            case .today: return "Today"
            case .tasks: return "Tasks"
            case .leads: return "Leads"
            case .clients: return "Clients"
            case .jobs: return "Jobs"
            case .schedule: return "Schedule"
            case .sending: return "Sending"
            }
        }
        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .tasks: return "checklist"
            case .leads: return "person.crop.circle.badge.plus"
            case .clients: return "person.2.fill"
            case .jobs: return "building.2.fill"
            case .schedule: return "calendar"
            case .sending: return "paperplane.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    laneSelector
                    laneContent
                        .transition(.opacity)
                        .id(lane)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .adaptiveContentWidth(AdaptiveLayout.workspaceWidth)
            }
            .background(AVIATheme.background)
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search clients & jobs")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingAddBuild) { AddBuildSheet() }
            .sheet(isPresented: $showAddTask) { addTaskSheet }
            .navigationDestination(for: ClientBuild.self) { build in ClientBuildDetailView(build: build) }
            .navigationDestination(for: ClientUser.self) { client in AdminClientCRMView(client: client) }
            .navigationDestination(for: Lead.self) { lead in AdminLeadDetailView(lead: lead) }
            .task { await load() }
            .refreshable { await load() }
        }
        .tint(AVIATheme.timelessBrown)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { resetNewTask(); showAddTask = true } label: {
                    Label("New Task", systemImage: "checklist")
                }
                Button { showingAddBuild = true } label: {
                    Label("New Build", systemImage: "plus.circle")
                }
                Divider()
                NavigationLink { AdminDashboardView() } label: {
                    Label("Full Dashboard", systemImage: "square.grid.2x2.fill")
                }
                NavigationLink { AdminBuildManagementView() } label: {
                    Label("Build Management", systemImage: "slider.horizontal.3")
                }
                NavigationLink { AdminCatalogHubView() } label: {
                    Label("Catalog Management", systemImage: "list.clipboard.fill")
                }
                NavigationLink { UserManagementView() } label: {
                    Label("Manage Users", systemImage: "person.badge.key.fill")
                }
                NavigationLink { PackageManagementView() } label: {
                    Label("Manage Packages", systemImage: "house.and.flag.fill")
                }
                NavigationLink { AdminEOIReviewView() } label: {
                    Label("EOI Reviews", systemImage: "doc.text.magnifyingglass")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(viewModel.currentUser.initials.isEmpty ? "?" : viewModel.currentUser.initials)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.brownGradient)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.neueCaption2Medium)
                        .tracking(0.8)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(greeting)
                        .font(.neueCorpMedium(26))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.warmAccent)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var greeting: String {
        let name = viewModel.currentUser.firstName
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return name.isEmpty ? part : "\(part), \(name)"
    }

    // MARK: - Lane selector

    private var laneSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(WorkflowLane.allCases) { l in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { lane = l }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: l.icon).font(.neueCorp(11))
                            Text(l.label).font(.neueCaptionMedium)
                            if let badge = laneBadge(l), badge > 0 {
                                Text("\(badge)")
                                    .font(.neueCorpMedium(9))
                                    .foregroundStyle(lane == l ? AVIATheme.timelessBrown : AVIATheme.aviaWhite)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .padding(.horizontal, 2)
                                    .background(lane == l ? AVIATheme.aviaWhite : AVIATheme.warning)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .foregroundStyle(lane == l ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                        .background(lane == l ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if lane != l {
                                Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func laneBadge(_ l: WorkflowLane) -> Int? {
        switch l {
        case .today: return todayItemCount
        case .tasks: return tasks.filter(\.isOverdue).count
        case .schedule: return upcomingScheduleCount
        default: return nil
        }
    }

    // MARK: - Lane content

    @ViewBuilder
    private var laneContent: some View {
        switch lane {
        case .today: todayLane
        case .tasks: tasksLane
        case .leads: AdminLeadsSection(searchText: searchText)
        case .clients: AdminClientsSection(searchText: searchText)
        case .jobs: jobsLane
        case .schedule: scheduleLane
        case .sending: sendingLane
        }
    }

    // MARK: - Today lane

    private var todayItemCount: Int {
        overdueTasks.count + dueTodayTasks.count + todaysAppointments.count + followUpsDue.count
    }

    private var overdueTasks: [ClientTask] { tasks.filter(\.isOverdue) }

    private var dueTodayTasks: [ClientTask] {
        let cal = Calendar.current
        return tasks.filter { task in
            guard !task.isOverdue, let due = task.dueAt else { return false }
            return cal.isDateInToday(due)
        }
    }

    private var todaysAppointments: [(clientId: String, item: ScheduleItem)] {
        scheduleItems.filter { Calendar.current.isDateInToday($0.item.date) }
    }

    private var weekAppointments: [(clientId: String, item: ScheduleItem)] {
        let cal = Calendar.current
        guard let weekEnd = cal.date(byAdding: .day, value: 7, to: .now) else { return [] }
        return scheduleItems.filter {
            !$0.item.isToday && $0.item.date > .now && $0.item.date <= weekEnd
        }
    }

    private var followUpsDue: [ClientCRMProfile] {
        let cutoff = Date.now.addingTimeInterval(86400 * 2)
        return crmProfiles.values
            .filter { ($0.nextFollowUpAt ?? .distantFuture) <= cutoff }
            .sorted { ($0.nextFollowUpAt ?? .distantFuture) < ($1.nextFollowUpAt ?? .distantFuture) }
    }

    private var todayLane: some View {
        VStack(spacing: 18) {
            todayMetrics
            actionRequiredPanel

            if isLoading && tasks.isEmpty && scheduleItems.isEmpty {
                ProgressView().padding(.vertical, 40)
            } else if todayItemCount == 0 {
                AdminEmptyState(icon: "checkmark.seal.fill", title: "You're all clear", subtitle: "Nothing due today. Enjoy the calm.")
            } else {
                if !overdueTasks.isEmpty {
                    feedSection(title: "OVERDUE", count: overdueTasks.count, tint: AVIATheme.warning) {
                        ForEach(overdueTasks) { task in taskRow(task) }
                    }
                }
                if !dueTodayTasks.isEmpty {
                    feedSection(title: "TASKS DUE TODAY", count: dueTodayTasks.count, tint: AVIATheme.timelessBrown) {
                        ForEach(dueTodayTasks) { task in taskRow(task) }
                    }
                }
                if !todaysAppointments.isEmpty {
                    feedSection(title: "TODAY'S SCHEDULE", count: todaysAppointments.count, tint: AVIATheme.timelessBrown) {
                        ForEach(todaysAppointments, id: \.item.id) { entry in appointmentRow(entry) }
                    }
                }
                if !followUpsDue.isEmpty {
                    feedSection(title: "FOLLOW-UPS DUE", count: followUpsDue.count, tint: AVIATheme.heritageBlue) {
                        ForEach(followUpsDue) { profile in followUpRow(profile) }
                    }
                }
                if !weekAppointments.isEmpty {
                    feedSection(title: "LATER THIS WEEK", count: weekAppointments.count, tint: AVIATheme.textSecondary) {
                        ForEach(weekAppointments, id: \.item.id) { entry in appointmentRow(entry) }
                    }
                }
            }
        }
    }

    private var todayMetrics: some View {
        HStack(spacing: 10) {
            AdminMetricCard(value: "\(dueTodayTasks.count)", label: "Due Today", icon: "checklist", color: AVIATheme.timelessBrown)
            AdminMetricCard(value: "\(overdueTasks.count)", label: "Overdue", icon: "exclamationmark.triangle.fill", color: AVIATheme.warning)
            AdminMetricCard(value: "\(todaysAppointments.count)", label: "Scheduled", icon: "calendar", color: AVIATheme.heritageBlue)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var actionRequiredPanel: some View {
        let pendingUsers = viewModel.allRegisteredUsers.filter { $0.role == .pending }.count
        let openRequests = viewModel.requests.filter { $0.status == .open }.count
        let pendingEOIs = viewModel.packageAssignments.filter { $0.eoiStatus == "submitted" || $0.eoiStatus == "resubmitted" }.count
        let specReviews = Set(viewModel.pendingSpecReviews
            .filter { $0.selectionType != .upgradeRequested && $0.selectionType != .upgradeAccepted }
            .map(\.buildId)).count
        let upgradesToPrice = viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeRequested }.count
        let total = pendingUsers + openRequests + pendingEOIs + specReviews + upgradesToPrice

        if total > 0 {
            BentoCard(cornerRadius: 13) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(AVIATheme.warning)
                        Text("Action Required")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text("\(total)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 24, height: 24)
                            .background(AVIATheme.warning)
                            .clipShape(Circle())
                    }
                    VStack(spacing: 6) {
                        if pendingUsers > 0 {
                            actionRow(icon: "person.badge.clock.fill", text: "\(pendingUsers) user\(pendingUsers == 1 ? "" : "s") awaiting a role", color: AVIATheme.warning) { UserManagementView() }
                        }
                        if openRequests > 0 {
                            actionRow(icon: "bubble.left.fill", text: "\(openRequests) open client request\(openRequests == 1 ? "" : "s")", color: AVIATheme.timelessBrown) { RequestsView() }
                        }
                        if pendingEOIs > 0 {
                            actionRow(icon: "doc.text.magnifyingglass", text: "\(pendingEOIs) EOI\(pendingEOIs == 1 ? "" : "s") awaiting review", color: AVIATheme.warning) { AdminEOIReviewView() }
                        }
                        if specReviews > 0 {
                            actionRow(icon: "checklist.checked", text: "\(specReviews) build\(specReviews == 1 ? "" : "s") awaiting spec review", color: AVIATheme.warning) { AdminBuildManagementView() }
                        }
                        if upgradesToPrice > 0 {
                            actionRow(icon: "dollarsign.circle.fill", text: "\(upgradesToPrice) upgrade\(upgradesToPrice == 1 ? "" : "s") to price", color: AVIATheme.accent) { AdminBuildManagementView() }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func actionRow<Destination: View>(icon: String, text: String, color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.neueCorp(12))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                Text(text)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCorp(9))
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(10)
            .background(AVIATheme.cardBackgroundAlt)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.pressable(.subtle))
    }

    private func feedSection<Content: View>(title: String, count: Int, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text("\(count)")
                    .font(.neueCorpMedium(9))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(tint.opacity(0.14))
                    .clipShape(Capsule())
                Spacer()
            }
            content()
        }
    }

    // MARK: - Tasks lane

    private var tasksLane: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(tasks.count)", label: "Open", icon: "tray.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(tasks.filter { $0.assigneeId == viewModel.currentUser.id }.count)", label: "Mine", icon: "person.fill", color: AVIATheme.success)
                AdminMetricCard(value: "\(overdueTasks.count)", label: "Overdue", icon: "exclamationmark.triangle.fill", color: AVIATheme.warning)
            }
            .fixedSize(horizontal: false, vertical: true)

            Button { resetNewTask(); showAddTask = true } label: {
                AdminQuickActionContent(icon: "plus.circle.fill", label: "Add Task", color: AVIATheme.timelessBrown)
            }
            .buttonStyle(.pressable(.subtle))

            NavigationLink { AdminTasksInboxView() } label: {
                AdminQuickActionContent(icon: "tray.full.fill", label: "Open Full Task Board", color: AVIATheme.heritageBlue)
            }
            .buttonStyle(.pressable(.subtle))

            if isLoading && tasks.isEmpty {
                ProgressView().padding(.vertical, 40)
            } else if tasks.isEmpty {
                AdminEmptyState(icon: "checklist", title: "All caught up", subtitle: "No open tasks right now.")
            } else {
                ForEach(tasks) { task in taskRow(task) }
            }
        }
    }

    // MARK: - Jobs lane

    private var jobsLane: some View {
        let builds = filteredBuilds
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(viewModel.allClientBuilds.count)", label: "Total Jobs", icon: "building.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)", label: "Active", icon: "hammer.fill", color: AVIATheme.warning)
            }
            .fixedSize(horizontal: false, vertical: true)

            NavigationLink { AdminBuildManagementView() } label: {
                AdminQuickActionContent(icon: "slider.horizontal.3", label: "Build Management", color: AVIATheme.heritageBlue)
            }
            .buttonStyle(.pressable(.subtle))

            if builds.isEmpty {
                AdminEmptyState(icon: "building.2", title: "No jobs found", subtitle: searchText.isEmpty ? "New builds will appear here." : "Try a different search.")
            } else {
                ForEach(builds) { build in
                    let badge = BuildReviewBadgeResolver.resolve(for: build.id, viewModel: viewModel)
                    NavigationLink(value: build) {
                        AdminBuildRow(build: build, specReviewStatus: badge)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
    }

    private var filteredBuilds: [ClientBuild] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return viewModel.allClientBuilds }
        return viewModel.allClientBuilds.filter {
            $0.clientDisplayName.localizedStandardContains(q) ||
            $0.homeDesign.localizedStandardContains(q) ||
            $0.lotNumber.localizedStandardContains(q) ||
            $0.estate.localizedStandardContains(q)
        }
    }

    // MARK: - Schedule lane

    private var upcomingScheduleItems: [(clientId: String, item: ScheduleItem)] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        return scheduleItems
            .filter { $0.item.date >= startOfToday }
            .sorted { $0.item.date < $1.item.date }
    }

    private var upcomingScheduleCount: Int { upcomingScheduleItems.count }

    private var scheduleLane: some View {
        let items = upcomingScheduleItems
        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.item.date) }
        let days = grouped.keys.sorted()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(todaysAppointments.count)", label: "Today", icon: "calendar.circle.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(weekAppointments.count)", label: "This Week", icon: "calendar", color: AVIATheme.heritageBlue)
            }
            .fixedSize(horizontal: false, vertical: true)

            if isLoading && scheduleItems.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if items.isEmpty {
                AdminEmptyState(icon: "calendar.badge.exclamationmark", title: "Nothing scheduled", subtitle: "Add milestones from a client's record.")
            } else {
                ForEach(days, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayHeader(day))
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                        ForEach(grouped[day] ?? [], id: \.item.id) { entry in
                            appointmentRow(entry)
                        }
                    }
                }
            }
        }
    }

    private func dayHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY · " + date.formatted(.dateTime.weekday(.wide)) }
        if cal.isDateInTomorrow(date) { return "TOMORROW · " + date.formatted(.dateTime.weekday(.wide)) }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased()
    }

    // MARK: - Sending lane

    private var sendingClients: [ClientUser] {
        var clients = viewModel.allRegisteredUsers.filter { $0.role == .client }
        clients = Array(Dictionary(grouping: clients, by: \.id).compactMap(\.value.first))
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            clients = clients.filter { $0.fullName.localizedStandardContains(q) || $0.email.localizedStandardContains(q) }
        }
        return clients.sorted { $0.lastName < $1.lastName }
    }

    private var sendingLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            BentoCard(cornerRadius: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(width: 40, height: 40)
                        .background(AVIATheme.timelessBrown.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Documents & Sending")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Open a client to compose and send from your Microsoft account, and see what's been opened.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
            }

            NavigationLink { AdminDocumentLibraryView() } label: {
                BentoCard(cornerRadius: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 36, height: 36)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(.rect(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage stock library")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Upload reusable files your team can send to any client.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .padding(14)
                }
            }
            .buttonStyle(.pressable(.subtle))

            Text("PICK A CLIENT")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            if sendingClients.isEmpty {
                AdminEmptyState(icon: "person.2.slash", title: "No clients found", subtitle: searchText.isEmpty ? "Clients will appear here." : "Try a different search.")
            } else {
                ForEach(sendingClients) { client in
                    NavigationLink(value: client) {
                        sendingClientRow(client)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
    }

    private func sendingClientRow(_ client: ClientUser) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Text(client.initials.isEmpty ? "?" : client.initials)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 40, height: 40)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(client.email)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .padding(12)
        }
    }

    // MARK: - Shared rows

    private func client(for id: String?) -> ClientUser? {
        guard let id else { return nil }
        return viewModel.allRegisteredUsers.first { $0.id == id }
    }

    private func clientName(for id: String?) -> String {
        guard let id else { return "General task" }
        return viewModel.allRegisteredUsers.first { $0.id == id }?.fullName ?? "Client"
    }

    @ViewBuilder
    private func taskRow(_ task: ClientTask) -> some View {
        if let c = client(for: task.clientId) {
            NavigationLink(value: c) { taskRowContent(task) }
                .buttonStyle(.plain)
        } else {
            taskRowContent(task)
        }
    }

    private func taskRowContent(_ task: ClientTask) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(alignment: .top, spacing: 12) {
                Button { toggleComplete(task) } label: {
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
                        Image(systemName: "person.fill").font(.neueCaption2)
                        Text(clientName(for: task.clientId)).font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.textSecondary)
                    if let due = task.dueAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.neueCaption2)
                            Text(due.formatted(date: .abbreviated, time: .shortened)).font(.neueCaption2)
                            if task.isOverdue {
                                Text("OVERDUE").font(.neueCaption2Medium)
                            }
                        }
                        .foregroundStyle(task.isOverdue ? AVIATheme.warning : AVIATheme.textTertiary)
                    }
                }
                Spacer()
                if task.clientId != nil {
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(12)
        }
    }

    private func appointmentRow(_ entry: (clientId: String, item: ScheduleItem)) -> some View {
        let item = entry.item
        let owner = client(for: entry.clientId)
        return Group {
            if let owner {
                NavigationLink(value: owner) { appointmentRowContent(item: item, owner: owner) }
                    .buttonStyle(.plain)
            } else {
                appointmentRowContent(item: item, owner: nil)
            }
        }
    }

    private func appointmentRowContent(item: ScheduleItem, owner: ClientUser?) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: item.iconColor)
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 38, height: 38)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 6) {
                        if let owner {
                            Text(owner.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? owner.email : owner.fullName)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                        }
                        Text(item.type.rawValue)
                            .font(.neueCorpMedium(8))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(AVIATheme.timelessBrown.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if !item.isToday {
                        Text(item.date.formatted(.relative(presentation: .named)))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
            }
            .padding(12)
        }
    }

    private func followUpRow(_ profile: ClientCRMProfile) -> some View {
        let owner = client(for: profile.clientId)
        return Group {
            if let owner {
                NavigationLink(value: owner) { followUpRowContent(profile: profile, owner: owner) }
                    .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }

    private func followUpRowContent(profile: ClientCRMProfile, owner: ClientUser) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: profile.leadTemperature.icon)
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(AVIATheme.heritageBlue)
                    .frame(width: 38, height: 38)
                    .background(AVIATheme.heritageBlue.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(owner.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? owner.email : owner.fullName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: profile.leadStatus.icon).font(.neueCaption2)
                        Text(profile.leadStatus.label).font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
                if let next = profile.nextFollowUpAt {
                    Text(next.formatted(.relative(presentation: .named)))
                        .font(.neueCaption2Medium)
                        .foregroundStyle(next < .now ? AVIATheme.warning : AVIATheme.textSecondary)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Add task

    private var clientOptions: [ClientUser] {
        let clients = viewModel.allRegisteredUsers.filter { $0.role == .client }
        return Array(Dictionary(grouping: clients, by: \.id).compactMap(\.value.first))
            .sorted { $0.lastName < $1.lastName }
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

    private func resetNewTask() {
        newTaskTitle = ""
        newTaskDetail = ""
        newTaskDue = .now.addingTimeInterval(86400)
        newTaskPriority = .normal
        newTaskHasDue = true
        newTaskClientId = nil
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
        backgroundSave("Couldn't save the task — check your connection and try again.") {
            await SupabaseService.shared.upsertClientTask(task)
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
        backgroundSave("Couldn't update the task — check your connection and try again.") {
            await SupabaseService.shared.upsertClientTask(updated)
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        async let openTasks = SupabaseService.shared.fetchAllOpenClientTasks()
        async let profiles = SupabaseService.shared.fetchAllCRMProfiles()
        async let schedule = SupabaseService.shared.fetchAllScheduleItems()

        let (loadedTasks, loadedProfiles, loadedSchedule) = await (openTasks, profiles, schedule)
        tasks = loadedTasks
        var map: [String: ClientCRMProfile] = [:]
        for profile in loadedProfiles { map[profile.clientId] = profile }
        crmProfiles = map
        scheduleItems = loadedSchedule
        isLoading = false
    }
}
