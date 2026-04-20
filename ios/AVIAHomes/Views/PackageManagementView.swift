import SwiftUI

struct PackageManagementView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedPackage: HouseLandPackage?
    @State private var packageToEdit: HouseLandPackage?
    @State private var showCreatePackage = false
    @State private var quickAssignPackage: HouseLandPackage?
    @State private var searchText = ""
    @State private var selectedFilter: ResponseFilter = .all
    @State private var convertContext: ConvertBuildContext?
    @State private var packageToDelete: HouseLandPackage?

    enum ResponseFilter: String {
        case all, pending, accepted, declined
    }

    /// Carries all the info needed to launch AddBuildSheet prefilled from an accepted package.
    struct ConvertBuildContext: Identifiable {
        let id = UUID()
        let package: HouseLandPackage
        let clientId: String
        let assignmentId: String
        let designId: String?
    }

    private var filteredPackages: [HouseLandPackage] {
        var packages = viewModel.allPackages
        if !searchText.isEmpty {
            packages = packages.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.location.localizedStandardContains(searchText) ||
                $0.estate.localizedStandardContains(searchText)
            }
        }

        if selectedFilter != .all {
            let targetStatus: PackageResponseStatus = {
                switch selectedFilter {
                case .pending: return .pending
                case .accepted: return .accepted
                case .declined: return .declined
                case .all: return .pending
                }
            }()
            packages = packages.filter { pkg in
                guard let assignment = viewModel.assignmentForPackage(pkg.id) else { return false }
                return assignment.clientResponses.contains { $0.status == targetStatus }
            }
        }
        return packages
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                createPackageBanner
                summaryStats
                eoiReviewsLink
                packagesList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Packages")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreatePackage = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .hapticRefresh {
            await viewModel.refreshBuildsAndAssignments()
        }
        .sheet(isPresented: $showCreatePackage) {
            AdminPackageEditorView()
        }
        .sheet(item: $packageToEdit) { pkg in
            AdminPackageEditorView(existingPackage: pkg)
        }
        .sheet(item: $selectedPackage) { pkg in
            PackageAssignmentSheet(package: pkg)
        }
        .sheet(item: $quickAssignPackage) { pkg in
            QuickAssignSheet(package: pkg)
        }
        .sheet(item: $convertContext) { ctx in
            AddBuildSheet(
                prefillFrom: ctx.package,
                clientId: ctx.clientId,
                assignmentId: ctx.assignmentId,
                designId: ctx.designId
            )
        }
        .alert("Delete package?", isPresented: Binding(
            get: { packageToDelete != nil },
            set: { if !$0 { packageToDelete = nil } }
        ), presenting: packageToDelete) { pkg in
            Button("Delete", role: .destructive) {
                viewModel.deletePackage(pkg.id)
                packageToDelete = nil
            }
            Button("Cancel", role: .cancel) { packageToDelete = nil }
        } message: { pkg in
            Text("\"\(pkg.title)\" will be permanently removed along with all its assignments. This cannot be undone.")
        }
    }

    private var createPackageBanner: some View {
        Button { showCreatePackage = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AVIATheme.aviaWhite)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create New Package")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Text("Build a package and assign it to clients")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.5))
            }
            .padding(16)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 16))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showCreatePackage)
    }

    private var summaryStats: some View {
        let allResponses = viewModel.packageAssignments.flatMap(\.clientResponses)
        let pendingCount = allResponses.filter { $0.status == .pending }.count
        let acceptedCount = allResponses.filter { $0.status == .accepted }.count
        let declinedCount = allResponses.filter { $0.status == .declined }.count

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                BentoCard(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        BentoIconCircle(icon: "square.grid.2x2.fill", color: AVIATheme.timelessBrown)
                        Text("\(viewModel.allPackages.count)")
                            .font(.neueCorpMedium(32))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Total")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                BentoCard(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        BentoIconCircle(icon: "paperplane.fill", color: AVIATheme.success)
                        let sharedCount = viewModel.packageAssignments.filter { !$0.sharedWithClientIds.isEmpty }.count
                        Text("\(sharedCount)")
                            .font(.neueCorpMedium(32))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Shared")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 12) {
                statFilterCard(filter: .pending, label: "Pending", count: pendingCount, icon: "clock.fill", color: AVIATheme.warning)
                statFilterCard(filter: .accepted, label: "Accepted", count: acceptedCount, icon: "checkmark.circle.fill", color: AVIATheme.success)
                statFilterCard(filter: .declined, label: "Declined", count: declinedCount, icon: "xmark.circle.fill", color: AVIATheme.destructive)
            }

            if selectedFilter != .all {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Filtered by \(selectedFilter.rawValue.capitalized)")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedFilter = .all }
                    } label: {
                        Text("Clear")
                            .font(.neueCorpMedium(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AVIATheme.timelessBrown.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statFilterCard(filter: ResponseFilter, label: String, count: Int, icon: String, color: Color) -> some View {
        let isActive = selectedFilter == filter
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFilter = isActive ? .all : filter
            }
        } label: {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: icon, color: color)
                    Text("\(count)")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(label)
                        .font(.neueCaption)
                        .foregroundStyle(isActive ? color : AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressable(.standard))
    }

    private var eoiReviewsLink: some View {
        let eoiAssignments = viewModel.packageAssignments.filter { $0.eoiStatus != "none" }
        let submittedCount = eoiAssignments.filter { $0.eoiStatus == "submitted" || $0.eoiStatus == "resubmitted" }.count

        return NavigationLink {
            AdminEOIReviewView()
        } label: {
            BentoCard(cornerRadius: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EOI Submissions")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Review and manage all expressions of interest")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    if submittedCount > 0 {
                        Text("\(submittedCount)")
                            .font(.neueCorpMedium(11))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 24, height: 24)
                            .background(AVIATheme.warning)
                            .clipShape(Circle())
                    }
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)
            }
        }
        .buttonStyle(.pressable(.subtle))
    }

    private var packagesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPackages) { pkg in
                packageManagementCard(package: pkg)
            }
        }
    }

    private func packageManagementCard(package: HouseLandPackage) -> some View {
        let assignment = viewModel.assignmentForPackage(package.id)
        return BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(width: 64, height: 64)
                        .overlay {
                            AsyncImage(url: URL(string: package.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.title)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(package.price)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Text("•")
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(package.specTier.displayName)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(14)

                if let assignment, (!assignment.assignedPartnerIds.isEmpty || !assignment.sharedWithClientIds.isEmpty) {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                    HStack(spacing: 12) {
                        if !assignment.sharedWithClientIds.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AVIATheme.success)
                                Text("\(assignment.sharedWithClientIds.count) client\(assignment.sharedWithClientIds.count == 1 ? "" : "s")")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }

                        if !assignment.assignedPartnerIds.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text("\(assignment.assignedPartnerIds.count) partner\(assignment.assignedPartnerIds.count == 1 ? "" : "s")")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }

                        Spacer()

                        let pendingCount = assignment.clientResponses.filter { $0.status == .pending }.count
                        if pendingCount > 0 {
                            Text("\(pendingCount) pending")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.warning.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        let acceptedCount = assignment.clientResponses.filter { $0.status == .accepted }.count
                        if acceptedCount > 0 {
                            Text("\(acceptedCount) accepted")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.success.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        let declinedCount = assignment.clientResponses.filter { $0.status == .declined }.count
                        if declinedCount > 0 {
                            Text("\(declinedCount) declined")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.destructive)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.destructive.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    // EOI status indicator
                    if assignment.eoiStatus != "none" {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                        HStack(spacing: 8) {
                            Image(systemName: eoiStatusIcon(assignment.eoiStatus))
                                .font(.system(size: 10))
                                .foregroundStyle(eoiStatusColor(assignment.eoiStatus))
                            Text("EOI: \(eoiStatusLabel(assignment.eoiStatus))")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(eoiStatusColor(assignment.eoiStatus))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(eoiStatusColor(assignment.eoiStatus).opacity(0.1))
                                .clipShape(Capsule())

                            if assignment.convertedToBuildId != nil {
                                Text("Confirmed • Build Created")
                                    .font(.neueCorpMedium(9))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AVIATheme.timelessBrown.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    } else if assignment.convertedToBuildId != nil {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Text("Confirmed • Build Created")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.timelessBrown.opacity(0.1))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }

                // Contextual action row driven by the selected filter.
                contextualActionRow(package: package, assignment: viewModel.assignmentForPackage(package.id))

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                HStack(spacing: 0) {
                    Button {
                        quickAssignPackage = package
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Assign")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .sensoryFeedback(.selection, trigger: quickAssignPackage?.id)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 28)

                    Button {
                        packageToEdit = package
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Edit")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 28)

                    Button {
                        selectedPackage = package
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Manage")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contextualActionRow(package: HouseLandPackage, assignment: PackageAssignment?) -> some View {
        // Only show the contextual row when the admin has selected a status filter.
        if selectedFilter == .accepted,
           let assignment,
           assignment.convertedToBuildId == nil,
           let acceptingResponse = assignment.clientResponses.first(where: { $0.status == .accepted }) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
            HStack(spacing: 0) {
                Button {
                    let designId = viewModel.findDesign(byName: package.homeDesign)?.id
                    convertContext = ConvertBuildContext(
                        package: package,
                        clientId: acceptingResponse.clientId,
                        assignmentId: assignment.id,
                        designId: designId
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Convert to Build")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AVIATheme.primaryGradient)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: convertContext?.id)
            }
        } else if selectedFilter == .declined, assignment?.convertedToBuildId == nil {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
            HStack(spacing: 0) {
                Button(role: .destructive) {
                    packageToDelete = package
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Delete Package")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AVIATheme.destructive.opacity(0.08))
                }
            }
        }
    }

    private func eoiStatusLabel(_ status: String) -> String {
        switch status {
        case "submitted", "resubmitted": "Submitted"
        case "approved": "Approved"
        case "declined": "Declined"
        case "changes_requested": "Changes Requested"
        default: status.capitalized
        }
    }

    private func eoiStatusColor(_ status: String) -> Color {
        switch status {
        case "submitted", "resubmitted": AVIATheme.warning
        case "approved": AVIATheme.success
        case "declined": AVIATheme.destructive
        case "changes_requested": AVIATheme.warning
        default: AVIATheme.textTertiary
        }
    }

    private func eoiStatusIcon(_ status: String) -> String {
        switch status {
        case "submitted", "resubmitted": "doc.text.fill"
        case "approved": "checkmark.seal.fill"
        case "declined": "xmark.circle.fill"
        case "changes_requested": "exclamationmark.bubble.fill"
        default: "doc.text.fill"
        }
    }
}

struct QuickAssignSheet: View {
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var assignment: PackageAssignment? {
        viewModel.assignmentForPackage(package.id)
    }

    private var sharedIds: Set<String> {
        Set(assignment?.sharedWithClientIds ?? [])
    }

    private var allClients: [ClientUser] {
        let clients = viewModel.clientUsers
        if searchText.isEmpty { return clients }
        return clients.filter {
            $0.fullName.localizedStandardContains(searchText) ||
            $0.email.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                packageHeader

                if !sharedIds.isEmpty {
                    assignedSummary
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(allClients, id: \.id) { client in
                            let isShared = sharedIds.contains(client.id)
                            let response = viewModel.clientResponseForPackage(package.id, clientId: client.id)

                            Button {
                                if isShared {
                                    viewModel.removeClientFromPackage(packageId: package.id, clientId: client.id)
                                } else {
                                    viewModel.sharePackageWithClient(packageId: package.id, clientId: client.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(client.initials.isEmpty ? "?" : client.initials)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.aviaWhite)
                                        .frame(width: 38, height: 38)
                                        .background(isShared ? AVIATheme.primaryGradient : LinearGradient(colors: [AVIATheme.surfaceElevated], startPoint: .top, endPoint: .bottom))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        if isShared, let response {
                                            Text(response.status.rawValue)
                                                .font(.neueCaption2)
                                                .foregroundStyle(responseColor(response.status))
                                        } else {
                                            Text(client.email)
                                                .font(.neueCaption2)
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }
                                    }

                                    Spacer()

                                    if isShared {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(AVIATheme.surfaceBorder)
                                    }
                                }
                                .padding(12)
                                .background(isShared ? AVIATheme.timelessBrown.opacity(0.04) : Color.clear)
                                .clipShape(.rect(cornerRadius: 14))
                            }
                            .sensoryFeedback(.selection, trigger: isShared)
                        }

                        if allClients.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("No clients found")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .background(AVIATheme.background)
            .navigationTitle("Assign to Clients")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search clients")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var packageHeader: some View {
        HStack(spacing: 14) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 48, height: 48)
                .overlay {
                    AsyncImage(url: URL(string: package.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(package.title)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                Text(package.price)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var assignedSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.success)
            Text("\(sharedIds.count) client\(sharedIds.count == 1 ? "" : "s") assigned")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()

            let pendingCount = (assignment?.clientResponses ?? []).filter { $0.status == .pending }.count
            if pendingCount > 0 {
                Text("\(pendingCount) pending")
                    .font(.neueCorpMedium(9))
                    .foregroundStyle(AVIATheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AVIATheme.warning.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AVIATheme.success.opacity(0.04))
    }

    private func responseColor(_ status: PackageResponseStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .accepted: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}

struct PackageAssignmentSheet: View {
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                packageHeader

                Picker("Section", selection: $selectedSection) {
                    Text("Partners").tag(0)
                    Text("Share with Clients").tag(1)
                    Text("Responses").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedSection {
                        case 0: partnerAssignmentSection
                        case 1: clientSharingSection
                        case 2: responsesSection
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .background(AVIATheme.background)
            .navigationTitle("Manage Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var packageHeader: some View {
        HStack(spacing: 14) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 56, height: 56)
                .overlay {
                    AsyncImage(url: URL(string: package.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(package.title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                HStack(spacing: 8) {
                    Text(package.price)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("•")
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(package.estate)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private var partnerAssignmentSection: some View {
        let assignment = viewModel.assignmentForPackage(package.id)
        let assignedIds = assignment?.assignedPartnerIds ?? []

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ASSIGNED PARTNERS")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()

                Button {
                    viewModel.togglePackageExclusive(packageId: package.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: assignment?.isExclusive == true ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 10))
                        Text(assignment?.isExclusive == true ? "Exclusive" : "Open")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(assignment?.isExclusive == true ? AVIATheme.warning : AVIATheme.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(assignment?.isExclusive == true ? AVIATheme.warning.opacity(0.1) : AVIATheme.surfaceElevated)
                    .clipShape(Capsule())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: assignment?.isExclusive)
            }

            let partners = viewModel.partnerUsers
            let uniquePartners = Dictionary(grouping: partners, by: \.id).compactMap(\.value.first)

            ForEach(uniquePartners, id: \.id) { partner in
                let isAssigned = assignedIds.contains(partner.id)
                Button {
                    if isAssigned {
                        viewModel.removePartnerFromPackage(packageId: package.id, partnerId: partner.id)
                    } else {
                        viewModel.assignPartnerToPackage(packageId: package.id, partnerId: partner.id)
                    }
                } label: {
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Text(partner.initials.isEmpty ? "?" : partner.initials)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .frame(width: 38, height: 38)
                                .background(AVIATheme.timelessBrown)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(partner.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? partner.email : partner.fullName)
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(partner.email)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            Spacer()

                            Image(systemName: isAssigned ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isAssigned ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                        }
                        .padding(12)
                    }
                }
                .sensoryFeedback(.selection, trigger: isAssigned)
            }

            if uniquePartners.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No partners registered")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var clientSharingSection: some View {
        let assignment = viewModel.assignmentForPackage(package.id)
        let sharedIds = assignment?.sharedWithClientIds ?? []

        return VStack(alignment: .leading, spacing: 12) {
            Text("SHARE WITH CLIENTS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            let clients = viewModel.clientUsers
            let uniqueClients = Dictionary(grouping: clients, by: \.id).compactMap(\.value.first)

            ForEach(uniqueClients, id: \.id) { client in
                let isShared = sharedIds.contains(client.id)
                Button {
                    if isShared {
                        viewModel.removeClientFromPackage(packageId: package.id, clientId: client.id)
                    } else {
                        viewModel.sharePackageWithClient(packageId: package.id, clientId: client.id)
                    }
                } label: {
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Text(client.initials.isEmpty ? "?" : client.initials)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .frame(width: 38, height: 38)
                                .background(AVIATheme.primaryGradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                if isShared {
                                    let response = viewModel.clientResponseForPackage(package.id, clientId: client.id)
                                    Text(response?.status.rawValue ?? "Shared")
                                        .font(.neueCaption2)
                                        .foregroundStyle(responseColor(response?.status))
                                } else {
                                    Text(client.email)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }

                            Spacer()

                            if isShared {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AVIATheme.surfaceBorder)
                            }
                        }
                        .padding(12)
                    }
                }
                .sensoryFeedback(.selection, trigger: isShared)
            }

            if uniqueClients.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No clients registered")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var responsesSection: some View {
        let assignment = viewModel.assignmentForPackage(package.id)
        let responses = assignment?.clientResponses ?? []

        return VStack(alignment: .leading, spacing: 12) {
            Text("CLIENT RESPONSES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            if responses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No responses yet")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text("Share this package with clients to receive responses")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(responses) { response in
                    let client = viewModel.clientUsers.first { $0.id == response.clientId }
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: response.status.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(responseColor(response.status))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(client?.fullName ?? "Unknown Client")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                if let date = response.respondedDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                                if let notes = response.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text(response.status.rawValue)
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(responseColor(response.status))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(responseColor(response.status).opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(12)
                    }
                }
            }
        }
    }

    private func responseColor(_ status: PackageResponseStatus?) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .accepted: AVIATheme.success
        case .declined: AVIATheme.destructive
        case nil: AVIATheme.textTertiary
        }
    }
}
