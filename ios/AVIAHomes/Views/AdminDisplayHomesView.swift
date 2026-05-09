import SwiftUI

struct AdminDisplayHomesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab: Tab = .visits
    @State private var editingHome: DisplayHome?
    @State private var showingNewHome = false
    @State private var selectedVisit: DisplayHomeVisit?

    enum Tab: String, CaseIterable, Identifiable {
        case visits = "Visits"
        case homes = "Homes"
        var id: String { rawValue }
    }

    private var visits: [DisplayHomeVisit] {
        viewModel.displayHomeVisits.sorted { $0.requestedAt > $1.requestedAt }
    }

    private var pendingCount: Int {
        viewModel.displayHomeVisits.filter { $0.status == .pending }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab == .visits && pendingCount > 0 ? "\(tab.rawValue) (\(pendingCount))" : tab.rawValue)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case .visits: visitsContent
                    case .homes: homesContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Display Homes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewHome = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingNewHome) {
            AdminDisplayHomeEditorSheet(home: .blank, isNew: true)
        }
        .sheet(item: $editingHome) { home in
            AdminDisplayHomeEditorSheet(home: home, isNew: false)
        }
        .sheet(item: $selectedVisit) { visit in
            AdminDisplayHomeVisitSheet(visit: visit)
        }
        .task { await viewModel.reloadDisplayHomes() }
        .refreshable { await viewModel.reloadDisplayHomes() }
    }

    // MARK: - Visits

    @ViewBuilder
    private var visitsContent: some View {
        if visits.isEmpty {
            emptyState(icon: "calendar", title: "No visit requests yet", subtitle: "Client visit requests will appear here.")
        } else {
            ForEach(visits) { visit in
                Button { selectedVisit = visit } label: {
                    AdminVisitRow(visit: visit, home: viewModel.allDisplayHomes.first { $0.id == visit.displayHomeId })
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    // MARK: - Homes

    @ViewBuilder
    private var homesContent: some View {
        if viewModel.allDisplayHomes.isEmpty {
            emptyState(icon: "house.lodge", title: "No display homes yet", subtitle: "Tap + to add your first display home listing.")
        } else {
            ForEach(viewModel.allDisplayHomes.sorted { $0.sortOrder < $1.sortOrder }) { home in
                Button { editingHome = home } label: {
                    AdminHomeRow(home: home)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(AVIATheme.textTertiary)
            Text(title)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text(subtitle)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Rows

private struct AdminVisitRow: View {
    let visit: DisplayHomeVisit
    let home: DisplayHome?

    var body: some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 12) {
                Image(systemName: visit.status.icon)
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(visit.status.color)
                    .frame(width: 40, height: 40)
                    .background(visit.status.color.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(visit.attendeeName.isEmpty ? "Unknown attendee" : visit.attendeeName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(home?.name ?? "Display home")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(visit.requestedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
                StatusBadge(title: visit.status.label, color: visit.status.color)
            }
            .padding(14)
        }
    }
}

private struct AdminHomeRow: View {
    let home: DisplayHome

    var body: some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 64, height: 64)
                    .overlay {
                        if let urlString = home.primaryImageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                            .allowsHitTesting(false)
                        } else {
                            Image(systemName: "house.lodge.fill")
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.4))
                        }
                    }
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(home.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(home.estate.isEmpty ? home.suburb : home.estate)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                    HStack(spacing: 8) {
                        Label("\(home.bedrooms)", systemImage: "bed.double.fill")
                        Label("\(home.bathrooms)", systemImage: "shower.fill")
                        Label("\(home.garages)", systemImage: "car.fill")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
                StatusBadge(
                    title: home.isActive ? "Active" : "Hidden",
                    color: home.isActive ? AVIATheme.success : AVIATheme.textTertiary
                )
            }
            .padding(12)
        }
    }
}

// MARK: - Visit detail sheet

struct AdminDisplayHomeVisitSheet: View {
    let visit: DisplayHomeVisit
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel

    @State private var workingVisit: DisplayHomeVisit
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    init(visit: DisplayHomeVisit) {
        self.visit = visit
        _workingVisit = State(initialValue: visit)
    }

    private var home: DisplayHome? {
        viewModel.allDisplayHomes.first { $0.id == workingVisit.displayHomeId }
    }

    private var staff: [ClientUser] {
        viewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display home") {
                    Text(home?.name ?? "Unknown")
                        .font(.neueSubheadlineMedium)
                    if let suburb = home?.suburb, !suburb.isEmpty {
                        Text(suburb).foregroundStyle(AVIATheme.textSecondary)
                    }
                }

                Section("Visit") {
                    DatePicker("Scheduled", selection: $workingVisit.requestedAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Duration: \(workingVisit.durationMinutes) min", value: $workingVisit.durationMinutes, in: 15...180, step: 15)
                    Stepper("Party size: \(workingVisit.partySize)", value: $workingVisit.partySize, in: 1...20)

                    Picker("Status", selection: $workingVisit.status) {
                        ForEach(DisplayHomeVisitStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }

                    Picker("Host", selection: hostBinding) {
                        Text("Unassigned").tag(String?.none)
                        ForEach(staff) { user in
                            Text(user.fullName).tag(String?.some(user.id))
                        }
                    }
                }

                Section("Attendee") {
                    LabeledContent("Name", value: workingVisit.attendeeName.isEmpty ? "—" : workingVisit.attendeeName)
                    LabeledContent("Email", value: workingVisit.attendeeEmail.isEmpty ? "—" : workingVisit.attendeeEmail)
                    LabeledContent("Phone", value: workingVisit.attendeePhone.isEmpty ? "—" : workingVisit.attendeePhone)
                    if !workingVisit.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Client notes").font(.neueCaption2Medium).foregroundStyle(AVIATheme.textTertiary)
                            Text(workingVisit.notes).font(.neueCaption)
                        }
                    }
                }

                Section("Internal notes") {
                    TextField("Notes for the team", text: $workingVisit.adminNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete visit", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().controlSize(.small) } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog("Delete this visit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await remove() } }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var hostBinding: Binding<String?> {
        Binding(
            get: { workingVisit.assignedStaffId },
            set: { workingVisit.assignedStaffId = $0 }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var v = workingVisit
        // Stamp lifecycle timestamps if status changed.
        if v.status != visit.status {
            switch v.status {
            case .confirmed: v.confirmedAt = .now
            case .completed: v.completedAt = .now
            case .cancelled: v.cancelledAt = .now
            default: break
            }
        }
        v.updatedAt = .now
        let ok = await viewModel.updateDisplayHomeVisit(v)
        if ok { dismiss() }
    }

    private func remove() async {
        isSaving = true
        defer { isSaving = false }
        let ok = await viewModel.deleteDisplayHomeVisit(id: workingVisit.id)
        if ok { dismiss() }
    }
}

// MARK: - Home editor sheet

struct AdminDisplayHomeEditorSheet: View {
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel

    @State private var working: DisplayHome
    @State private var imageURLsText: String
    @State private var featuresText: String
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    init(home: DisplayHome, isNew: Bool) {
        self.isNew = isNew
        _working = State(initialValue: home)
        _imageURLsText = State(initialValue: home.imageURLs.joined(separator: "\n"))
        _featuresText = State(initialValue: home.features.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Listing") {
                    TextField("Name", text: $working.name)
                    TextField("Estate", text: $working.estate)
                    TextField("Address", text: $working.address)
                    TextField("Suburb", text: $working.suburb)
                    Toggle("Active (visible to clients)", isOn: $working.isActive)
                    Stepper("Sort order: \(working.sortOrder)", value: $working.sortOrder, in: 0...999)
                }

                Section("Specs") {
                    Stepper("Bedrooms: \(working.bedrooms)", value: $working.bedrooms, in: 0...10)
                    Stepper("Bathrooms: \(working.bathrooms)", value: $working.bathrooms, in: 0...10)
                    Stepper("Garages: \(working.garages)", value: $working.garages, in: 0...6)
                    HStack {
                        Text("Square metres")
                        Spacer()
                        TextField("0", value: $working.squareMeters, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }

                Section("Visiting") {
                    TextField("Opening hours", text: $working.openingHours)
                    TextField("Contact phone", text: $working.contactPhone)
                        .keyboardType(.phonePad)
                }

                Section("Description") {
                    TextField("About this display home", text: $working.description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    TextField("Image URLs (one per line)", text: $imageURLsText, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } header: { Text("Images") }
                footer: { Text("First image is shown as the cover.") }

                Section("Features (one per line)") {
                    TextField("Features", text: $featuresText, axis: .vertical)
                        .lineLimit(3...8)
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete display home", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Display Home" : "Edit Display Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().controlSize(.small) } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving || working.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this display home?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await remove() } }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func parsedLines(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var home = working
        home.imageURLs = parsedLines(imageURLsText)
        home.features = parsedLines(featuresText)
        home.updatedAt = .now
        let ok = await viewModel.saveDisplayHome(home)
        if ok { dismiss() }
    }

    private func remove() async {
        isSaving = true
        defer { isSaving = false }
        let ok = await viewModel.deleteDisplayHome(id: working.id)
        if ok { dismiss() }
    }
}
