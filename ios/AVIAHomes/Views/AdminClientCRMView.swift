import SwiftUI

struct AdminClientCRMView: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser

    @State private var activities: [ClientActivity] = []
    @State private var isLoading: Bool = true
    @State private var pushedConversation: Conversation?
    @State private var selectedFilter: ActivityFilter = .all

    @State private var crmProfile: ClientCRMProfile = .empty(clientId: "")
    @State private var notes: [ClientNote] = []
    @State private var tasks: [ClientTask] = []
    @State private var isLoadingCRM: Bool = true

    @State private var showAddNote: Bool = false
    @State private var newNoteBody: String = ""
    @State private var editingNote: ClientNote?

    @State private var showAddTask: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskDetail: String = ""
    @State private var newTaskDue: Date = .now.addingTimeInterval(86400)
    @State private var newTaskPriority: TaskPriority = .normal
    @State private var newTaskHasDue: Bool = true

    @State private var showAddTag: Bool = false
    @State private var newTagText: String = ""

    enum ActivityFilter: String, CaseIterable, Identifiable {
        case all, designs, floorplans, specs, enquiries
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .designs: return "Designs"
            case .floorplans: return "Plans"
            case .specs: return "Specs"
            case .enquiries: return "Enquiries"
            }
        }
        func matches(_ kind: ClientActivityKind) -> Bool {
            switch self {
            case .all: return true
            case .designs: return kind == .designView
            case .floorplans: return kind == .floorplanDownload
            case .specs: return kind == .specRangeView
            case .enquiries: return kind == .enquirySent
            }
        }
    }

    private var clientBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.hasClient(id: client.id) }
    }

    private var filteredActivities: [ClientActivity] {
        activities.filter { selectedFilter.matches($0.kind) }
    }

    private var designViews: [ClientActivity] { activities.filter { $0.kind == .designView } }
    private var floorplanDownloads: [ClientActivity] { activities.filter { $0.kind == .floorplanDownload } }
    private var specViews: [ClientActivity] { activities.filter { $0.kind == .specRangeView } }
    private var enquiries: [ClientActivity] { activities.filter { $0.kind == .enquirySent } }

    private var topDesigns: [(name: String, count: Int)] {
        topItems(from: designViews, limit: 3)
    }

    private var topSpecs: [(name: String, count: Int)] {
        topItems(from: specViews, limit: 3)
    }

    private func topItems(from list: [ClientActivity], limit: Int) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: list, by: \.referenceName)
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    /// Lead score derived from recent activity + status.
    private var leadScore: Int {
        var score = 0
        score += min(designViews.count * 5, 30)
        score += min(floorplanDownloads.count * 10, 30)
        score += min(specViews.count * 4, 20)
        score += min(enquiries.count * 15, 30)
        if let last = activities.first {
            let days = Calendar.current.dateComponents([.day], from: last.createdAt, to: .now).day ?? 99
            if days <= 3 { score += 10 } else if days <= 7 { score += 5 }
        }
        switch crmProfile.leadStatus {
        case .qualified, .proposal, .negotiation: score += 10
        case .won: score += 20
        case .lost: score = max(0, score - 30)
        default: break
        }
        return min(score, 100)
    }

    private var leadScoreColor: Color {
        if leadScore >= 70 { return AVIATheme.success }
        if leadScore >= 40 { return AVIATheme.warning }
        return AVIATheme.textTertiary
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeader
                statusAndScoreCard
                tagsCard
                quickActions
                metricsGrid
                tasksSection
                notesSection
                if !topDesigns.isEmpty || !topSpecs.isEmpty {
                    interestsSection
                }
                lastSeenCard
                activityTimeline
            }
            .padding(16)
        }
        .background(AVIATheme.background)
        .navigationTitle("Client CRM")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation)
        }
        .task {
            crmProfile = .empty(clientId: client.id)
            await loadActivity()
            await loadCRM()
        }
        .refreshable {
            await loadActivity()
            await loadCRM()
        }
        .sheet(isPresented: $showAddNote) {
            addNoteSheet
        }
        .sheet(item: $editingNote) { note in
            editNoteSheet(note: note)
        }
        .sheet(isPresented: $showAddTask) {
            addTaskSheet
        }
        .alert("Add Tag", isPresented: $showAddTag) {
            TextField("Tag name", text: $newTagText)
            Button("Cancel", role: .cancel) { newTagText = "" }
            Button("Add") { addTag() }
        }
    }

    // MARK: - Loading

    private func loadActivity() async {
        isLoading = true
        let result = await SupabaseService.shared.fetchClientActivity(clientId: client.id, limit: 300)
        activities = result
        isLoading = false
    }

    private func loadCRM() async {
        isLoadingCRM = true
        async let profile = SupabaseService.shared.fetchCRMProfile(clientId: client.id)
        async let notesList = SupabaseService.shared.fetchClientNotes(clientId: client.id)
        async let tasksList = SupabaseService.shared.fetchClientTasks(clientId: client.id)
        let p = await profile
        crmProfile = p ?? .empty(clientId: client.id)
        notes = await notesList
        tasks = await tasksList
        isLoadingCRM = false
    }

    private func saveProfile() {
        let snapshot = crmProfile
        Task { await SupabaseService.shared.upsertCRMProfile(snapshot) }
    }

    // MARK: - Sections

    private var profileHeader: some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(client.initials.isEmpty ? "?" : client.initials)
                        .font(.neueCorpMedium(22))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 64, height: 64)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(2)
                        Text(client.email)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                        if !client.phone.isEmpty {
                            Text(client.phone)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    Spacer()
                }

                if !clientBuilds.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTIVE BUILDS")
                            .font(.neueCaption2Medium)
                            .tracking(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        ForEach(clientBuilds) { build in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(build.overallProgress >= 0.7 ? AVIATheme.success : build.overallProgress > 0 ? AVIATheme.warning : AVIATheme.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text(build.homeDesign)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Spacer()
                                Text("\(Int(build.overallProgress * 100))%")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private var statusAndScoreCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LEAD STATUS")
                            .font(.neueCaption2Medium)
                            .tracking(1.2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Menu {
                            ForEach(LeadStatus.allCases) { status in
                                Button {
                                    crmProfile.leadStatus = status
                                    saveProfile()
                                } label: {
                                    Label(status.label, systemImage: status.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: crmProfile.leadStatus.icon)
                                Text(crmProfile.leadStatus.label)
                                Image(systemName: "chevron.down")
                                    .font(.neueCaption2)
                            }
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(.capsule)
                        }
                        Menu {
                            ForEach(LeadTemperature.allCases) { temp in
                                Button {
                                    crmProfile.leadTemperature = temp
                                    saveProfile()
                                } label: {
                                    Label(temp.label, systemImage: temp.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: crmProfile.leadTemperature.icon)
                                Text(crmProfile.leadTemperature.label)
                            }
                            .font(.neueCaption2Medium)
                            .foregroundStyle(temperatureColor(crmProfile.leadTemperature))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(temperatureColor(crmProfile.leadTemperature).opacity(0.15))
                            .clipShape(.capsule)
                        }
                    }
                    Spacer()
                    leadScoreRing
                }

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    if let next = crmProfile.nextFollowUpAt {
                        Text("Follow up \(next.formatted(.relative(presentation: .named)))")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textPrimary)
                    } else {
                        Text("No follow-up scheduled")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    Menu {
                        Button("Tomorrow") { setFollowUp(daysFromNow: 1) }
                        Button("In 3 days") { setFollowUp(daysFromNow: 3) }
                        Button("Next week") { setFollowUp(daysFromNow: 7) }
                        Button("In 2 weeks") { setFollowUp(daysFromNow: 14) }
                        if crmProfile.nextFollowUpAt != nil {
                            Divider()
                            Button("Clear", role: .destructive) {
                                crmProfile.nextFollowUpAt = nil
                                saveProfile()
                            }
                        }
                    } label: {
                        Text(crmProfile.nextFollowUpAt == nil ? "Set" : "Edit")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                }
            }
            .padding(16)
        }
    }

    private func setFollowUp(daysFromNow days: Int) {
        crmProfile.nextFollowUpAt = Calendar.current.date(byAdding: .day, value: days, to: .now)
        saveProfile()
    }

    private func temperatureColor(_ temp: LeadTemperature) -> Color {
        switch temp {
        case .hot: return AVIATheme.warning
        case .warm: return AVIATheme.timelessBrown
        case .cold: return AVIATheme.textSecondary
        }
    }

    private var leadScoreRing: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(AVIATheme.surfaceBorder, lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(leadScore) / 100)
                    .stroke(leadScoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: leadScore)
                Text("\(leadScore)")
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            Text("LEAD SCORE")
                .font(.neueCaption2Medium)
                .tracking(0.8)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private var tagsCard: some View {
        BentoCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TAGS")
                        .font(.neueCaption2Medium)
                        .tracking(1.2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    Button {
                        newTagText = ""
                        showAddTag = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    .buttonStyle(.plain)
                }
                if crmProfile.tags.isEmpty {
                    Text("No tags yet — add labels like 'Priority', 'Investor', or 'First Home'.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                } else {
                    FlexibleTagFlow(tags: crmProfile.tags) { tag in
                        crmProfile.tags.removeAll { $0 == tag }
                        saveProfile()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !crmProfile.tags.contains(trimmed) else {
            newTagText = ""
            return
        }
        crmProfile.tags.append(trimmed)
        newTagText = ""
        saveProfile()
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await openConversation() }
            } label: {
                quickActionLabel(icon: "bubble.left.and.bubble.right.fill", label: "Message")
            }
            if !client.phone.isEmpty,
               let phoneURL = URL(string: "tel:\(client.phone.replacingOccurrences(of: " ", with: ""))") {
                Link(destination: phoneURL) {
                    quickActionLabel(icon: "phone.fill", label: "Call")
                }
                .simultaneousGesture(TapGesture().onEnded { markContactedNow() })
            }
            if let emailURL = URL(string: "mailto:\(client.email)") {
                Link(destination: emailURL) {
                    quickActionLabel(icon: "envelope.fill", label: "Email")
                }
                .simultaneousGesture(TapGesture().onEnded { markContactedNow() })
            }
        }
    }

    private func markContactedNow() {
        crmProfile.lastContactedAt = .now
        saveProfile()
    }

    private func quickActionLabel(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 38, height: 38)
                .background(AVIATheme.primaryGradient)
                .clipShape(Circle())
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private func openConversation() async {
        let convId = await viewModel.messagingService.getOrCreateConversation(
            currentUserId: viewModel.currentUser.id,
            otherUserId: client.id
        )
        if let conv = viewModel.messagingService.conversations.first(where: { $0.id == convId }) {
            pushedConversation = conv
        }
        markContactedNow()
    }

    private var metricsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(designViews.count)", label: "Design Views", icon: "house.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(floorplanDownloads.count)", label: "Floorplans", icon: "arrow.down.doc.fill", color: AVIATheme.success)
            }
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(specViews.count)", label: "Spec Views", icon: "square.stack.3d.up.fill", color: AVIATheme.warning)
                AdminMetricCard(value: "\(enquiries.count)", label: "Enquiries", icon: "paperplane.fill", color: AVIATheme.timelessBrown)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FOLLOW-UPS & TASKS")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                Button {
                    resetNewTask()
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .buttonStyle(.plain)
            }

            if tasks.isEmpty {
                BentoCard(cornerRadius: 12) {
                    Text("No tasks. Tap + to schedule a follow-up call, send pricing, or remind yourself to check in.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRow(task: task)
                    }
                }
            }
        }
    }

    private func taskRow(task: ClientTask) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleTaskComplete(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.neueTitle3)
                        .foregroundStyle(task.isCompleted ? AVIATheme.success : AVIATheme.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(task.isCompleted ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                        .strikethrough(task.isCompleted)
                    if let detail = task.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        if let due = task.dueAt {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.neueCaption2)
                                Text(due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.neueCaption2)
                            }
                            .foregroundStyle(task.isOverdue ? AVIATheme.warning : AVIATheme.textTertiary)
                        }
                        priorityBadge(task.priority)
                        if task.isOverdue {
                            Text("OVERDUE")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.warning)
                        }
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Image(systemName: "trash")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        let color: Color = {
            switch priority {
            case .high: return AVIATheme.warning
            case .normal: return AVIATheme.timelessBrown
            case .low: return AVIATheme.textTertiary
            }
        }()
        return Text(priority.label.uppercased())
            .font(.neueCaption2Medium)
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(.capsule)
    }

    private func resetNewTask() {
        newTaskTitle = ""
        newTaskDetail = ""
        newTaskDue = .now.addingTimeInterval(86400)
        newTaskPriority = .normal
        newTaskHasDue = true
    }

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $newTaskTitle)
                    TextField("Details (optional)", text: $newTaskDetail, axis: .vertical)
                        .lineLimit(2...5)
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
            clientId: client.id,
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
        Task {
            await SupabaseService.shared.upsertClientTask(task)
            await loadCRM()
        }
    }

    private func toggleTaskComplete(_ task: ClientTask) {
        var updated = task
        updated.completedAt = task.isCompleted ? nil : .now
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = updated
        }
        Task { await SupabaseService.shared.upsertClientTask(updated) }
    }

    private func deleteTask(_ task: ClientTask) {
        tasks.removeAll { $0.id == task.id }
        Task { await SupabaseService.shared.deleteClientTask(id: task.id) }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOTES")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                Button {
                    newNoteBody = ""
                    showAddNote = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .buttonStyle(.plain)
            }

            if notes.isEmpty {
                BentoCard(cornerRadius: 12) {
                    Text("No notes yet. Capture call summaries, client preferences, or budget discussions here.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        noteRow(note: note)
                    }
                }
            }
        }
    }

    private func noteRow(note: ClientNote) -> some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if note.pinned {
                        Image(systemName: "pin.fill")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.warning)
                    }
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    Menu {
                        Button {
                            togglePin(note)
                        } label: {
                            Label(note.pinned ? "Unpin" : "Pin", systemImage: "pin")
                        }
                        Button {
                            editingNote = note
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                Text(note.body)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
    }

    private var addNoteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a private admin note for this client.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                TextEditor(text: $newNoteBody)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                Spacer()
            }
            .padding(16)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddNote = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNewNote() }
                        .disabled(newNoteBody.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func editNoteSheet(note: ClientNote) -> some View {
        EditNoteSheet(initialBody: note.body) { newBody in
            var updated = note
            updated.body = newBody
            updated.updatedAt = .now
            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                notes[idx] = updated
            }
            editingNote = nil
            Task { await SupabaseService.shared.upsertClientNote(updated) }
        } onCancel: {
            editingNote = nil
        }
    }

    private func saveNewNote() {
        let trimmed = newNoteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = ClientNote(
            id: UUID().uuidString,
            clientId: client.id,
            authorId: viewModel.currentUser.id,
            body: trimmed,
            pinned: false,
            createdAt: .now,
            updatedAt: .now
        )
        notes.insert(note, at: 0)
        showAddNote = false
        newNoteBody = ""
        Task {
            await SupabaseService.shared.upsertClientNote(note)
            await loadCRM()
        }
    }

    private func togglePin(_ note: ClientNote) {
        var updated = note
        updated.pinned.toggle()
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = updated
        }
        notes.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
        Task { await SupabaseService.shared.upsertClientNote(updated) }
    }

    private func deleteNote(_ note: ClientNote) {
        notes.removeAll { $0.id == note.id }
        Task { await SupabaseService.shared.deleteClientNote(id: note.id) }
    }

    // MARK: - Existing sections

    private var interestsSection: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 14) {
                Text("TOP INTERESTS")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)

                if !topDesigns.isEmpty {
                    interestList(title: "Designs", icon: "house.fill", items: topDesigns)
                }
                if !topSpecs.isEmpty {
                    if !topDesigns.isEmpty {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    }
                    interestList(title: "Spec Ranges", icon: "square.stack.3d.up.fill", items: topSpecs)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func interestList(title: String, icon: String, items: [(name: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text(title)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(item.count) view\(item.count == 1 ? "" : "s")")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AVIATheme.warmAccent)
                        .clipShape(.capsule)
                }
            }
        }
    }

    private var lastSeenCard: some View {
        BentoCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 32, height: 32)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Activity")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                    if let last = activities.first {
                        Text("\(last.kind.label) · \(last.referenceName)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Text(last.createdAt.formatted(.relative(presentation: .named)))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    } else if isLoading {
                        Text("Loading…")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    } else {
                        Text("No activity tracked yet")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                Spacer()
                if let last = crmProfile.lastContactedAt {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Contacted")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(last.formatted(.relative(presentation: .named)))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
            }
            .padding(14)
        }
    }

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVITY TIMELINE")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.label)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(selectedFilter == filter ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background {
                                    if selectedFilter == filter {
                                        AVIATheme.timelessBrown
                                    } else {
                                        AVIATheme.cardBackground
                                    }
                                }
                                .clipShape(.capsule)
                                .overlay {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)

            if isLoading && activities.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if filteredActivities.isEmpty {
                AdminEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No activity yet",
                    subtitle: "Client engagement will appear here as they explore the app"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                        ActivityTimelineRow(activity: activity, isLast: index == filteredActivities.count - 1)
                    }
                }
                .padding(14)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
            }
        }
    }
}

private struct EditNoteSheet: View {
    let initialBody: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $draft)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                Spacer()
            }
            .padding(16)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { draft = initialBody }
        }
    }
}

private struct FlexibleTagFlow: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 6) {
                    Text(tag)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Button {
                        onRemove(tag)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AVIATheme.warmAccent)
                .clipShape(.capsule)
            }
        }
    }
}

private struct ActivityTimelineRow: View {
    let activity: ClientActivity
    let isLast: Bool

    private var iconColor: Color {
        switch activity.kind {
        case .designView: return AVIATheme.timelessBrown
        case .floorplanDownload: return AVIATheme.success
        case .specRangeView: return AVIATheme.warning
        case .packageView: return AVIATheme.timelessBrown
        case .enquirySent: return AVIATheme.timelessBrown
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: activity.kind.icon)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 28, height: 28)
                    .background(iconColor)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.kind.label)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(activity.referenceName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : 14)

            Spacer()
        }
    }
}
