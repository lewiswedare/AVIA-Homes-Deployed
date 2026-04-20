import SwiftUI

struct AdminHandoverSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let build: ClientBuild

    @State private var buildingSupportStaff: [ClientUser] = []
    @State private var selectedStaffId: String = ""
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELECT BUILDING SUPPORT STAFF")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .kerning(0.5)

                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if buildingSupportStaff.isEmpty {
                                Text("No Building Support staff available")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .padding()
                            } else {
                                ForEach(buildingSupportStaff, id: \.id) { staff in
                                    Button {
                                        selectedStaffId = staff.id
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(staff.initials)
                                                .font(.neueCorpMedium(12))
                                                .foregroundStyle(AVIATheme.aviaWhite)
                                                .frame(width: 40, height: 40)
                                                .background(AVIATheme.primaryGradient)
                                                .clipShape(Circle())
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(staff.fullName)
                                                    .font(.neueSubheadlineMedium)
                                                    .foregroundStyle(AVIATheme.textPrimary)
                                                if let title = staff.displayTitle, !title.isEmpty {
                                                    Text(title)
                                                        .font(.neueCaption2)
                                                        .foregroundStyle(AVIATheme.textSecondary)
                                                }
                                            }
                                            Spacer()
                                            if selectedStaffId == staff.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(AVIATheme.success)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.pressable(.subtle))
                                }
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Trigger Handover", icon: "arrow.right.arrow.left", style: .primary) {
                        Task { await triggerHandover() }
                    }
                    .disabled(selectedStaffId.isEmpty || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Build Handover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .task {
                buildingSupportStaff = await SupabaseService.shared.fetchProfilesByRole(role: "BuildingSupport")
                isLoading = false
            }
        }
    }

    private func triggerHandover() async {
        isSaving = true
        defer { isSaving = false }

        let iso = ISO8601DateFormatter()
        let now = iso.string(from: .now)

        let fields: [String: String] = [
            "building_support_staff_id": selectedStaffId,
            "handover_triggered_at": now
        ]

        _ = await SupabaseService.shared.updateBuildFields(buildId: build.id, fields: fields)

        for clientId in build.allClientIds {
            await viewModel.notificationService.createNotification(
                recipientId: clientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .handoverTriggered,
                title: "Build Handover",
                message: "Your build has moved to construction phase — meet your Building Support contact",
                referenceId: build.id,
                referenceType: "build"
            )
        }

        await viewModel.refreshBuildsAndAssignments()
        dismiss()
    }
}

struct AdminBuildHandoverSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let build: ClientBuild
    @State private var showHandoverSheet = false
    @State private var preConStaff: ClientUser?
    @State private var buildSupportStaff: ClientUser?

    var body: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("STAFF & HANDOVER")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .kerning(0.5)

                if let staff = preConStaff {
                    staffRow(label: "Pre-Construction", user: staff)
                }
                if let staff = buildSupportStaff {
                    staffRow(label: "Building Support", user: staff)
                }

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                HStack {
                    Text("Handover Status")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    if let dateStr = build.handoverTriggeredAt, !dateStr.isEmpty {
                        let formatter = ISO8601DateFormatter()
                        let date = formatter.date(from: dateStr)
                        Text("Triggered \(date?.formatted(date: .abbreviated, time: .omitted) ?? dateStr)")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.success)
                    } else {
                        Text("Not triggered")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }

                if build.handoverTriggeredAt == nil, viewModel.currentRole.isAdmin {
                    PremiumButton("Trigger Handover", icon: "arrow.right.arrow.left", style: .secondary) {
                        showHandoverSheet = true
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showHandoverSheet) {
            AdminHandoverSheet(build: build)
        }
        .task {
            if let pcId = build.preConstructionStaffId, !pcId.isEmpty {
                preConStaff = await SupabaseService.shared.fetchProfile(userId: pcId)
            }
            if let bsId = build.buildingSupportStaffId, !bsId.isEmpty {
                buildSupportStaff = await SupabaseService.shared.fetchProfile(userId: bsId)
            }
        }
    }

    private func staffRow(label: String, user: ClientUser) -> some View {
        HStack(spacing: 10) {
            Text(user.initials)
                .font(.neueCorpMedium(10))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 30, height: 30)
                .background(AVIATheme.primaryGradient)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(user.fullName)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            Spacer()
        }
    }
}
