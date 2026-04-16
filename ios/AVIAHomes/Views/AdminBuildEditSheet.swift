import SwiftUI
import UniformTypeIdentifiers

struct AdminBuildEditSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild
    @State private var homeDesign: String
    @State private var lotNumber: String
    @State private var estate: String
    @State private var contractDate: Date
    @State private var selectedStaffId: String
    @State private var selectedSpecTier: String
    @State private var selectedTab: AdminEditTab = .details
    @State private var isSaving = false
    @State private var showingSaved = false
    @State private var editingStage: BuildStage?
    @State private var showingDeleteConfirmation = false
    @State private var showingAddClient = false
    @State private var showingRemoveClientConfirmation: ClientUser?
    @State private var buildDocuments: [ClientDocument] = []
    @State private var isLoadingDocs = false
    @State private var showingDocumentPicker = false
    @State private var showingUploadForm = false
    @State private var pendingDocName = ""
    @State private var pendingDocCategory: DocumentCategory = .contracts
    @State private var pendingDocStageId: String? = nil
    @State private var pendingDocData: Data? = nil
    @State private var pendingDocFileName = ""
    @State private var isUploadingDoc = false

    enum AdminEditTab: String, CaseIterable {
        case details = "Details"
        case clients = "Clients"
        case stages = "Stages"
        case timeline = "Timeline"
        case documents = "Docs"
        case selections = "Selections"

        var icon: String {
            switch self {
            case .details: "square.and.pencil"
            case .clients: "person.2.fill"
            case .stages: "chart.bar.fill"
            case .timeline: "calendar.badge.clock"
            case .documents: "doc.text.fill"
            case .selections: "paintpalette.fill"
            }
        }
    }

    init(build: ClientBuild) {
        self.build = build
        _homeDesign = State(initialValue: build.homeDesign)
        _lotNumber = State(initialValue: build.lotNumber)
        _estate = State(initialValue: build.estate)
        _contractDate = State(initialValue: build.contractDate)
        _selectedStaffId = State(initialValue: build.assignedStaffId)
        _selectedSpecTier = State(initialValue: build.specTier ?? "")
    }

    private var latestBuild: ClientBuild {
        viewModel.allClientBuilds.first { $0.id == build.id } ?? build
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    clientInfoHeader
                    tabPicker
                    tabContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(AVIATheme.teal)
                }
            }
            .overlay {
                if showingSaved {
                    savedConfirmation
                }
            }
            .sheet(item: $editingStage) { stage in
                StageEditSheet(build: build, stage: stage)
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientToBuildSheet(build: latestBuild)
            }
            .alert("Remove Client", isPresented: Binding(
                get: { showingRemoveClientConfirmation != nil },
                set: { if !$0 { showingRemoveClientConfirmation = nil } }
            )) {
                Button("Cancel", role: .cancel) { showingRemoveClientConfirmation = nil }
                Button("Remove", role: .destructive) {
                    if let client = showingRemoveClientConfirmation {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.removeClientFromBuild(buildId: build.id, clientId: client.id)
                        }
                        showingRemoveClientConfirmation = nil
                    }
                }
            } message: {
                if let client = showingRemoveClientConfirmation {
                    let isPrimary = build.client.id == client.id
                    let extra = isPrimary && build.additionalClients.isEmpty
                        ? " This build will become unassigned."
                        : ""
                    Text("Remove \(client.fullName) from this build? They will immediately lose access.\(extra)")
                }
            }
            .alert("Delete Build", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteBuild(buildId: build.id)
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this build and all associated data including stages, spec selections, and colour selections. This cannot be undone.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }

    private var clientInfoHeader: some View {
        HStack(spacing: 14) {
            Text(latestBuild.client.initials.isEmpty ? "?" : latestBuild.client.initials)
                .font(.neueCorpMedium(20))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AVIATheme.tealGradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(latestBuild.clientDisplayName)
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.textPrimary)
                if !latestBuild.additionalClients.isEmpty {
                    Text("\(latestBuild.allClients.count) clients assigned")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.teal)
                } else {
                    Text(latestBuild.client.email)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }

            Spacer()

            StatusBadge(
                title: build.statusLabel,
                color: build.overallProgress >= 0.7 ? AVIATheme.success : AVIATheme.teal
            )
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(AdminEditTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.neueCorp(10))
                            Text(tab.rawValue)
                                .font(.neueCaptionMedium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedTab == tab ? .white : AVIATheme.textSecondary)
                        .background(selectedTab == tab ? AVIATheme.teal : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if selectedTab != tab {
                                Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .details:
            detailsEditSection
        case .clients:
            clientsSection
        case .stages:
            stagesSection
        case .timeline:
            AdminBuildTimelineEditor(build: latestBuild)
        case .documents:
            documentsSection
        case .selections:
            selectionsSection
        }
    }

    // MARK: - Clients Section

    private var clientsSection: some View {
        VStack(spacing: 16) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Assigned Clients", systemImage: "person.2.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        StatusBadge(title: "\(latestBuild.allClients.count)", color: AVIATheme.teal)
                    }

                    if latestBuild.client.id.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No clients assigned")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                Text("Add a client to give them access to this build")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        clientRow(client: latestBuild.client, isPrimary: true)

                        ForEach(latestBuild.additionalClients, id: \.id) { additionalClient in
                            clientRow(client: additionalClient, isPrimary: false)
                        }
                    }
                }
                .padding(16)
            }

            Button {
                showingAddClient = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Client")
                }
                .font(.neueSubheadlineMedium)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AVIATheme.teal)
                    Text("Multiple Clients")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("You can assign multiple clients to the same build — useful when a couple both have accounts. All assigned clients will see this build in their dashboard.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }

            deleteBuildSection
        }
    }

    private func clientRow(client: ClientUser, isPrimary: Bool) -> some View {
        HStack(spacing: 12) {
            Text(client.initials.isEmpty ? "?" : client.initials)
                .font(.neueCorp(11))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AVIATheme.tealGradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if isPrimary {
                        Text("PRIMARY")
                            .font(.neueCorpMedium(7))
                            .kerning(0.3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AVIATheme.teal)
                            .clipShape(Capsule())
                    }
                }
                Text(client.email)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showingRemoveClientConfirmation = client
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AVIATheme.destructive.opacity(0.7))
            }
        }
        .padding(10)
        .background(isPrimary ? AVIATheme.teal.opacity(0.04) : Color.clear)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var deleteBuildSection: some View {
        VStack(spacing: 12) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                .padding(.vertical, 4)

            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Delete Build")
                }
                .font(.neueSubheadlineMedium)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(AVIATheme.destructive)
                .clipShape(.rect(cornerRadius: 14))
            }

            Text("This action is permanent and cannot be undone.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Details Section

    private var detailsEditSection: some View {
        VStack(spacing: 16) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Build Details", systemImage: "house.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    adminField(label: "Home Design", text: $homeDesign, icon: "house.fill")
                    adminField(label: "Lot Number", text: $lotNumber, icon: "number")
                    adminField(label: "Estate", text: $estate, icon: "mappin.circle.fill")

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Contract Date", systemImage: "calendar")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                        DatePicker("", selection: $contractDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AVIATheme.teal)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Spec Tier", systemImage: "crown.fill")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                        HStack(spacing: 8) {
                            ForEach(SpecTier.allCases) { tier in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSpecTier = tier.rawValue
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: tier.icon)
                                            .font(.system(size: 16))
                                        Text(tier.displayName)
                                            .font(.neueCaption2Medium)
                                        Text(tier.tagline)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(selectedSpecTier == tier.rawValue ? .white : AVIATheme.textSecondary)
                                    .background(selectedSpecTier == tier.rawValue ? AVIATheme.teal : AVIATheme.cardBackgroundAlt)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay {
                                        if selectedSpecTier != tier.rawValue {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Assigned Staff", systemImage: "person.badge.shield.checkmark.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    let staff = viewModel.staffUsers
                    if staff.isEmpty {
                        Text("No staff members available")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(staff, id: \.id) { member in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedStaffId = member.id
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(member.initials)
                                            .font(.neueCorp(11))
                                            .foregroundStyle(.white)
                                            .frame(width: 32, height: 32)
                                            .background(AVIATheme.tealGradient)
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(member.fullName)
                                                .font(.neueCaptionMedium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            Text(member.role.rawValue)
                                                .font(.neueCaption2)
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }

                                        Spacer()

                                        Image(systemName: selectedStaffId == member.id ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(selectedStaffId == member.id ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                    }
                                    .padding(10)
                                    .background(selectedStaffId == member.id ? AVIATheme.teal.opacity(0.06) : Color.clear)
                                    .clipShape(.rect(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Button(action: saveDetails) {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Changes")
                        }
                        .font(.neueSubheadlineMedium)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(isSaving)
        }
    }

    private func adminField(label: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            TextField(label, text: text)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(12)
                .background(AVIATheme.cardBackgroundAlt)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private var stagesSection: some View {
        VStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Build Stages", systemImage: "chart.bar.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text("\(Int(latestBuild.overallProgress * 100))% complete")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.teal)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AVIATheme.teal.opacity(0.1)).frame(height: 8)
                            Capsule().fill(AVIATheme.tealGradient).frame(width: max(0, geo.size.width * latestBuild.overallProgress), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(16)
            }

            registrationToggleCard

            ForEach(latestBuild.buildStages, id: \.id) { stage in
                Button {
                    editingStage = stage
                } label: {
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 14) {
                            stageStatusIcon(for: stage)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(stage.name)
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(stage.name == "Awaiting Registration" && stage.status != .completed ? AVIATheme.warning : AVIATheme.textPrimary)
                                    if stage.name == "Awaiting Registration" && stage.status != .completed {
                                        Image(systemName: "clock.badge.questionmark")
                                            .font(.system(size: 11))
                                            .foregroundStyle(AVIATheme.warning)
                                    }
                                }
                                HStack(spacing: 8) {
                                    Text(stage.status.rawValue)
                                        .font(.neueCaption)
                                        .foregroundStyle(statusColor(stage.status))
                                    if stage.progress > 0 && stage.progress < 1.0 {
                                        Text("·")
                                            .foregroundStyle(AVIATheme.textTertiary)
                                        Text("\(Int(stage.progress * 100))%")
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.teal)
                                    }
                                    if stage.name == "Awaiting Registration", let estDate = stage.estimatedEndDate {
                                        Text("·")
                                            .foregroundStyle(AVIATheme.textTertiary)
                                        Text("Est. \(estDate.formatted(.dateTime.month(.abbreviated).day()))")
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textSecondary)
                                    }
                                }
                            }

                            Spacer()

                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AVIATheme.teal.opacity(0.6))
                        }
                        .padding(14)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var registrationToggleCard: some View {
        let hasRegistration = latestBuild.awaitingRegistrationStage != nil
        return BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 18))
                    .foregroundStyle(hasRegistration ? AVIATheme.warning : AVIATheme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Awaiting Site Registration")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(hasRegistration ? "Registration stage is active" : "Add registration stage before construction")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                Spacer()

                if hasRegistration {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.removeAwaitingRegistrationStage(buildId: build.id)
                        }
                    } label: {
                        Text("Remove")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.destructive)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.destructive.opacity(0.1))
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.addAwaitingRegistrationStage(
                                buildId: build.id,
                                estimatedDate: Calendar.current.date(byAdding: .month, value: 2, to: .now),
                                notes: nil
                            )
                        }
                    } label: {
                        Text("Add")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.warning)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
        }
    }

    private func stageStatusIcon(for stage: BuildStage) -> some View {
        Group {
            if stage.name == "Awaiting Registration" && stage.status != .completed {
                Image(systemName: "clock.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AVIATheme.warning)
            } else {
                Image(systemName: stage.status == .completed ? "checkmark.circle.fill" : stage.status == .inProgress ? "circle.dotted.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor(stage.status))
            }
        }
    }

    private func statusColor(_ status: BuildStage.StageStatus) -> Color {
        switch status {
        case .completed: AVIATheme.success
        case .inProgress: AVIATheme.warning
        case .upcoming: AVIATheme.textTertiary
        case .delayed: AVIATheme.destructive
        }
    }

    private var documentsSection: some View {
        VStack(spacing: 12) {
            // Upload button
            Button {
                showingDocumentPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("Upload Document")
                }
                .font(.neueSubheadlineMedium)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }

            if isLoadingDocs {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if buildDocuments.isEmpty {
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No Documents Yet")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Upload PDFs to attach them to this build.")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            } else {
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        ForEach(Array(buildDocuments.enumerated()), id: \.element.id) { index, doc in
                            buildDocumentRow(doc)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            let deleted = await SupabaseService.shared.deleteDocumentFromBuild(documentId: doc.id)
                                            if deleted {
                                                withAnimation {
                                                    buildDocuments.removeAll { $0.id == doc.id }
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            if index < buildDocuments.count - 1 {
                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 56)
                            }
                        }
                    }
                }
            }

            // Document status summary
            if !buildDocuments.isEmpty {
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AVIATheme.success)
                        Text("Document Status")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        let totalDocs = buildDocuments.count
                        let newDocs = buildDocuments.filter { $0.isNew }.count

                        HStack(spacing: 20) {
                            docStatusItem(label: "Total", value: "\(totalDocs)", color: AVIATheme.teal)
                            docStatusItem(label: "New", value: "\(newDocs)", color: AVIATheme.warning)
                            docStatusItem(label: "Reviewed", value: "\(totalDocs - newDocs)", color: AVIATheme.success)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
        }
        .task(id: build.id) {
            isLoadingDocs = true
            let docs = await SupabaseService.shared.fetchDocuments(clientId: latestBuild.client.id)
            buildDocuments = docs.filter { $0.buildId == build.id || $0.buildId == nil }
            isLoadingDocs = false
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { data, fileName in
                pendingDocData = data
                pendingDocFileName = fileName
                pendingDocName = fileName.replacingOccurrences(of: ".pdf", with: "")
                showingDocumentPicker = false
                showingUploadForm = true
            }
        }
        .sheet(isPresented: $showingUploadForm) {
            uploadFormSheet
        }
        .overlay {
            if isUploadingDoc {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Uploading...")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 16))
                }
            }
        }
    }

    private func buildDocumentRow(_ doc: ClientDocument) -> some View {
        Group {
            if let urlStr = doc.fileURL, let url = URL(string: urlStr) {
                Link(destination: url) {
                    buildDocumentRowContent(doc)
                }
            } else {
                buildDocumentRowContent(doc)
                    .opacity(0.7)
            }
        }
    }

    private func buildDocumentRowContent(_ doc: ClientDocument) -> some View {
        HStack(spacing: 14) {
            BentoIconCircle(icon: doc.category.icon, color: AVIATheme.teal)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(doc.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if doc.isNew {
                        StatusBadge(title: "NEW", color: AVIATheme.teal)
                    }
                    if let stage = doc.buildStageName {
                        StatusBadge(title: stage, color: AVIATheme.warning)
                    }
                }
                HStack(spacing: 8) {
                    Text(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(doc.fileSize)
                }
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            }

            Spacer()

            Image(systemName: doc.fileURL != nil ? "arrow.down.circle.fill" : "arrow.down.circle")
                .foregroundStyle(doc.fileURL != nil ? AVIATheme.teal : AVIATheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var uploadFormSheet: some View {
        NavigationStack {
            Form {
                Section("Document Details") {
                    TextField("Document Name", text: $pendingDocName)

                    Picker("Category", selection: $pendingDocCategory) {
                        ForEach(DocumentCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    Picker("Build Stage", selection: $pendingDocStageId) {
                        Text("No specific stage").tag(nil as String?)
                        ForEach(latestBuild.buildStages) { stage in
                            Text(stage.name).tag(stage.id as String?)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("File")
                            .foregroundStyle(AVIATheme.textSecondary)
                        Spacer()
                        Text(pendingDocFileName)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                Section {
                    Button {
                        Task { await performUpload() }
                    } label: {
                        HStack {
                            Spacer()
                            if isUploadingDoc {
                                ProgressView()
                            } else {
                                Text("Upload")
                                    .font(.neueSubheadlineMedium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(pendingDocName.isEmpty || pendingDocData == nil || isUploadingDoc)
                }
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingUploadForm = false
                        pendingDocData = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func performUpload() async {
        guard let data = pendingDocData else { return }
        isUploadingDoc = true
        defer { isUploadingDoc = false }

        let stageName = pendingDocStageId.flatMap { stageId in
            latestBuild.buildStages.first { $0.id == stageId }?.name
        }

        if let doc = await SupabaseService.shared.uploadDocument(
            buildId: build.id,
            clientIds: latestBuild.allClientIds,
            name: pendingDocName,
            category: pendingDocCategory,
            fileData: data,
            fileName: pendingDocFileName,
            buildStageId: pendingDocStageId,
            buildStageName: stageName
        ) {
            buildDocuments.insert(doc, at: 0)
        }

        showingUploadForm = false
        pendingDocData = nil
        pendingDocName = ""
        pendingDocCategory = .contracts
        pendingDocStageId = nil
    }

    private func docStatusItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.neueCorpMedium(24))
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private var selectionsSection: some View {
        AdminBuildSelectionsTab(build: latestBuild)
    }

    private var savedConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AVIATheme.success)
            Text("Changes Saved")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }

    private func saveDetails() {
        isSaving = true
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            viewModel.updateBuildDetails(
                buildId: build.id,
                homeDesign: homeDesign,
                lotNumber: lotNumber,
                estate: estate,
                contractDate: contractDate,
                specTier: selectedSpecTier.isEmpty ? nil : selectedSpecTier
            )
            if !selectedStaffId.isEmpty {
                viewModel.assignStaffToBuild(buildId: build.id, staffId: selectedStaffId)
            }
            isSaving = false
            withAnimation(.spring(response: 0.4)) {
                showingSaved = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                showingSaved = false
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            onPick(data, url.lastPathComponent)
        }
    }
}
