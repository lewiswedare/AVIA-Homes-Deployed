import SwiftUI

/// Full record for a single inbound lead — edit details, assign an owner,
/// move it through the pipeline, log notes, and act (call/email).
struct AdminLeadDetailView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State var lead: Lead
    /// Called whenever the lead is saved or deleted so the parent list can refresh.
    var onChange: (Lead) -> Void = { _ in }
    var onDelete: (Lead) -> Void = { _ in }

    @State private var showEdit: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var notesDraft: String = ""
    @State private var isSavingNotes: Bool = false

    private var navTitle: String {
        switch lead.kind {
        case .lead: return "Lead"
        case .opportunity: return "Opportunity"
        case .client: return "Client"
        }
    }

    private var owner: ClientUser? {
        guard let id = lead.ownerId else { return nil }
        return viewModel.allRegisteredUsers.first { $0.id == id }
    }

    private var staffOptions: [ClientUser] {
        viewModel.staffUsers
            .filter { !$0.fullName.trimmingCharacters(in: .whitespaces).isEmpty || !$0.email.isEmpty }
            .sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                conversionBanner
                assignmentCard
                switch lead.kind {
                case .lead:
                    pipelineCard
                case .opportunity:
                    opportunityWorkflowCard
                case .client:
                    EmptyView()
                }
                if lead.message?.isEmpty == false {
                    inboundMessageCard
                }
                notesCard
                actionsRow
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit Details", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete Lead", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            LeadEditSheet(lead: lead) { updated in
                lead = updated
                persist()
            }
        }
        .alert("Delete this lead?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(lead)
                Task { await SupabaseService.shared.deleteLead(id: lead.id) }
                dismiss()
            }
        } message: {
            Text("This permanently removes \(lead.name.isEmpty ? "this lead" : lead.name) from your CRM.")
        }
        .onAppear { notesDraft = lead.notes ?? "" }
        .tint(AVIATheme.timelessBrown)
    }

    // MARK: - Header

    private var headerCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(lead.initials)
                        .font(.neueTitle3)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 56, height: 56)
                        .background(AVIATheme.brownGradient)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lead.name.isEmpty ? "Unnamed lead" : lead.name)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        HStack(spacing: 6) {
                            Image(systemName: lead.source.icon).font(.neueCaption2)
                            Text(lead.source.label).font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }

                if lead.email?.isEmpty == false || lead.phone?.isEmpty == false {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    VStack(spacing: 8) {
                        if let email = lead.email, !email.isEmpty {
                            contactRow(icon: "envelope.fill", text: email)
                        }
                        if let phone = lead.phone, !phone.isEmpty {
                            contactRow(icon: "phone.fill", text: phone)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.neueCaption2)
                    Text("Added \(lead.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.neueCaption2)
                    Spacer()
                    if lead.isConverted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Converted")
                        }
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.success)
                    }
                }
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(16)
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 22)
            Text(text)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Assignment

    private var assignmentCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ASSIGNED TO")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Menu {
                    Button {
                        lead.ownerId = nil
                        persist()
                    } label: {
                        Label("Unassigned", systemImage: lead.ownerId == nil ? "checkmark" : "person.crop.circle.badge.xmark")
                    }
                    Divider()
                    ForEach(staffOptions) { staff in
                        Button {
                            lead.ownerId = staff.id
                            persist()
                        } label: {
                            let name = staff.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? staff.email : staff.fullName
                            if lead.ownerId == staff.id {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: owner == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                            .font(.neueTitle3)
                            .foregroundStyle(owner == nil ? AVIATheme.textTertiary : AVIATheme.timelessBrown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owner.map { $0.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? $0.email : $0.fullName } ?? "Unassigned")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(owner == nil ? "Tap to assign an admin or staff member" : (owner?.role.rawValue ?? ""))
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .padding(12)
                    .background(AVIATheme.cardBackgroundAlt)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Pipeline

    private var pipelineCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 14) {
                Text("STATUS & TEMPERATURE")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LeadStatus.allCases) { status in
                            chip(label: status.label, icon: status.icon, isSelected: lead.status == status) {
                                lead.status = status
                                persist()
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)

                HStack(spacing: 8) {
                    ForEach(LeadTemperature.allCases) { temp in
                        chip(label: temp.label, icon: temp.icon, isSelected: lead.temperature == temp) {
                            lead.temperature = temp
                            persist()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func chip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.neueCaption2)
                Text(label).font(.neueCaption2Medium)
            }
            .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background { if isSelected { AVIATheme.timelessBrown } else { AVIATheme.cardBackgroundAlt } }
            .clipShape(.capsule)
            .overlay { Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inbound message

    private var inboundMessageCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Text("INBOUND MESSAGE")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(lead.message ?? "")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("NOTES")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    if (lead.notes ?? "") != notesDraft {
                        Button {
                            lead.notes = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesDraft
                            persist()
                        } label: {
                            Text("Save")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                }
                TextField("Add notes about this lead…", text: $notesDraft, axis: .vertical)
                    .font(.neueCaption)
                    .lineLimit(3...8)
                    .padding(10)
                    .background(AVIATheme.cardBackgroundAlt)
                    .clipShape(.rect(cornerRadius: 10))
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 10) {
            if let phone = lead.phone, !phone.isEmpty,
               let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                Link(destination: url) {
                    actionLabel(icon: "phone.fill", title: "Call")
                }
            }
            if let email = lead.email, !email.isEmpty,
               let url = URL(string: "mailto:\(email)") {
                Link(destination: url) {
                    actionLabel(icon: "envelope.fill", title: "Email")
                }
            }
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.neueCorp(13))
            Text(title).font(.neueCaptionMedium)
        }
        .foregroundStyle(AVIATheme.aviaWhite)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AVIATheme.timelessBrown)
        .clipShape(.rect(cornerRadius: 11))
    }

    // MARK: - Conversion banner

    @ViewBuilder
    private var conversionBanner: some View {
        switch lead.kind {
        case .lead:
            Button {
                convertToOpportunity()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.neueSubheadlineMedium)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Convert to Opportunity")
                            .font(.neueCaptionMedium)
                        Text("Open the full sales workflow to win this deal.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "arrow.right").font(.neueCaption)
                }
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 13))
            }
            .buttonStyle(.pressable(.subtle))
        case .client:
            BentoCard(cornerRadius: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.neueTitle3)
                        .foregroundStyle(AVIATheme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Converted to client")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(lead.convertedAt.map { "Build contract allocated \($0.formatted(.relative(presentation: .named)))" } ?? "Build contract allocated.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
            }
        case .opportunity:
            EmptyView()
        }
    }

    // MARK: - Opportunity workflow

    private var workflowSteps: [OpportunityStep] {
        OpportunityWorkflow.steps(for: lead.status)
    }

    private var completedStepCount: Int {
        workflowSteps.filter { lead.workflowCompletions.contains($0.id) }.count
    }

    private var canAdvanceStage: Bool {
        guard OpportunityWorkflow.nextStage(after: lead.status) != nil else { return false }
        if workflowSteps.isEmpty { return true }
        return completedStepCount >= max(1, workflowSteps.count - 1)
    }

    private var contractAllocated: Bool {
        lead.workflowCompletions.contains(OpportunityWorkflow.contractStepID)
    }

    private var canConvertToClient: Bool {
        OpportunityWorkflow.normalizedStage(lead.status) == .negotiation && contractAllocated
    }

    private var opportunityWorkflowCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                workflowHeader
                workflowStepper
                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                workflowChecklist
                workflowAdvanceButton
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var workflowHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SALES WORKFLOW")
                    .font(.neueCaption2Medium)
                    .kerning(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                HStack(spacing: 8) {
                    Image(systemName: OpportunityWorkflow.normalizedStage(lead.status).icon)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(OpportunityWorkflow.normalizedStage(lead.status).stageColor)
                    Text(OpportunityWorkflow.normalizedStage(lead.status).label)
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Text(OpportunityWorkflow.normalizedStage(lead.status).lifecycleSubtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !workflowSteps.isEmpty {
                VStack(spacing: 2) {
                    Text("\(completedStepCount)/\(workflowSteps.count)")
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("DONE")
                        .font(.neueCaption2Medium)
                        .kerning(0.8)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AVIATheme.warmAccent)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var workflowStepper: some View {
        HStack(spacing: 0) {
            ForEach(Array(OpportunityWorkflow.stages.enumerated()), id: \.element) { index, stage in
                let current = OpportunityWorkflow.normalizedStage(lead.status)
                let isCurrent = stage == current
                let isPast = stage.pipelineIndex < current.pipelineIndex
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isPast ? AVIATheme.success : (isCurrent ? stage.stageColor : AVIATheme.surfaceBorder))
                            .frame(width: isCurrent ? 26 : 18, height: isCurrent ? 26 : 18)
                        if isPast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AVIATheme.aviaWhite)
                        } else if isCurrent {
                            Circle().fill(AVIATheme.aviaWhite).frame(width: 8, height: 8)
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: lead.status)
                    Text(stage.label)
                        .font(.neueCaption2Medium)
                        .kerning(0.4)
                        .foregroundStyle(isCurrent ? AVIATheme.textPrimary : AVIATheme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                if index < OpportunityWorkflow.stages.count - 1 {
                    Rectangle()
                        .fill(isPast ? AVIATheme.success : AVIATheme.surfaceBorder)
                        .frame(height: 2)
                        .padding(.bottom, 22)
                }
            }
        }
    }

    private var workflowChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("STEPS FOR THIS STAGE")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            VStack(spacing: 8) {
                ForEach(workflowSteps) { step in
                    Button { toggleStep(step) } label: {
                        stepRow(step)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Tap a step to mark it done as you progress the deal.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private func stepRow(_ step: OpportunityStep) -> some View {
        let done = lead.workflowCompletions.contains(step.id)
        let isGate = step.id == OpportunityWorkflow.contractStepID
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(done ? AVIATheme.success : AVIATheme.textTertiary)
                .animation(.spring(response: 0.4), value: done)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.neueCaption2)
                        .foregroundStyle(done ? AVIATheme.success : AVIATheme.timelessBrown)
                    Text(step.title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .strikethrough(done, color: AVIATheme.textTertiary)
                    if isGate {
                        Text("GATE")
                            .font(.neueCaption2Medium)
                            .kerning(0.6)
                            .foregroundStyle(AVIATheme.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AVIATheme.warning.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }
                Text(step.detail)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(done ? AVIATheme.success.opacity(0.07) : AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(done ? AVIATheme.success.opacity(0.3) : AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var workflowAdvanceButton: some View {
        let stage = OpportunityWorkflow.normalizedStage(lead.status)
        HStack(spacing: 10) {
            if let prev = OpportunityWorkflow.previousStage(before: lead.status) {
                Button { moveStage(to: prev) } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }

            if stage == .negotiation {
                Button { convertToClient() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.neueSubheadlineMedium)
                        Text("Convert to Client").font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background { if canConvertToClient { AVIATheme.primaryGradient } else { AVIATheme.textTertiary.opacity(0.5) } }
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canConvertToClient)
            } else if let next = OpportunityWorkflow.nextStage(after: lead.status) {
                Button { moveStage(to: next) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: next.icon).font(.neueSubheadlineMedium)
                        Text("Advance to \(next.label)").font(.neueCaptionMedium)
                        Image(systemName: "arrow.right").font(.neueCaption)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background { if canAdvanceStage { AVIATheme.primaryGradient } else { AVIATheme.textTertiary.opacity(0.5) } }
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canAdvanceStage)
            }
        }
    }

    private func toggleStep(_ step: OpportunityStep) {
        if lead.workflowCompletions.contains(step.id) {
            lead.workflowCompletions.remove(step.id)
        } else {
            lead.workflowCompletions.insert(step.id)
        }
        persist()
    }

    private func moveStage(to stage: LeadStatus) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            lead.status = stage
        }
        persist()
    }

    private func convertToOpportunity() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            lead.kind = .opportunity
            if lead.status == .new || lead.status == .contacted || lead.status == .lost {
                lead.status = .qualified
            }
        }
        persist()
    }

    private func convertToClient() {
        guard canConvertToClient else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            lead.kind = .client
            lead.status = .won
            lead.convertedAt = .now
            if lead.convertedClientId == nil { lead.convertedClientId = UUID().uuidString }
        }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        lead.updatedAt = .now
        onChange(lead)
        let snapshot = lead
        Task { await SupabaseService.shared.upsertLead(snapshot) }
    }
}

// MARK: - Edit Sheet

struct LeadEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var lead: Lead
    var onSave: (Lead) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $lead.name)
                    TextField("Email", text: Binding(
                        get: { lead.email ?? "" },
                        set: { lead.email = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    TextField("Phone", text: Binding(
                        get: { lead.phone ?? "" },
                        set: { lead.phone = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                }
                Section("Source") {
                    Picker("Source", selection: $lead.source) {
                        ForEach(LeadSource.allCases) { s in
                            Label(s.label, systemImage: s.icon).tag(s)
                        }
                    }
                }
                if lead.kind == .opportunity {
                    Section("Deal") {
                        HStack {
                            Text("Estimated value")
                            Spacer()
                            TextField("$", value: $lead.estimatedValue, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Toggle("Expected close date", isOn: Binding(
                            get: { lead.expectedCloseDate != nil },
                            set: { lead.expectedCloseDate = $0 ? (lead.expectedCloseDate ?? .now.addingTimeInterval(14 * 86400)) : nil }
                        ))
                        if lead.expectedCloseDate != nil {
                            DatePicker("Closes", selection: Binding(
                                get: { lead.expectedCloseDate ?? .now },
                                set: { lead.expectedCloseDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                }
                Section("Inbound message") {
                    TextField("Message (optional)", text: Binding(
                        get: { lead.message ?? "" },
                        set: { lead.message = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...6)
                }
            }
            .navigationTitle("Edit Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(lead)
                        dismiss()
                    }
                    .disabled(lead.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
