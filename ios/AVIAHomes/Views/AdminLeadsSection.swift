import SwiftUI

/// Inbound leads workspace lane. New leads from the website and social media
/// land here for triage, assignment to an admin/staff member, and pipeline
/// management before they become registered clients.
struct AdminLeadsSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String

    @State private var leads: [Lead] = []
    @State private var isLoading: Bool = false
    @State private var sourceFilter: LeadSource? = nil
    @State private var ownerFilter: OwnerFilter = .all
    @State private var showAddLead: Bool = false

    enum OwnerFilter: String, CaseIterable, Identifiable {
        case all, mine, unassigned
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .mine: return "Mine"
            case .unassigned: return "Unassigned"
            }
        }
    }

    private var activeLeads: [Lead] {
        leads.filter { $0.status != .won && $0.status != .lost && !$0.isConverted }
    }

    private var unassignedCount: Int {
        leads.filter { $0.ownerId == nil && !$0.isConverted }.count
    }

    private var filteredLeads: [Lead] {
        var result = leads
        switch ownerFilter {
        case .all: break
        case .mine: result = result.filter { $0.ownerId == viewModel.currentUser.id }
        case .unassigned: result = result.filter { $0.ownerId == nil }
        }
        if let source = sourceFilter {
            result = result.filter { $0.source == source }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            result = result.filter {
                $0.name.localizedStandardContains(q) ||
                ($0.email?.localizedStandardContains(q) ?? false) ||
                ($0.phone?.localizedStandardContains(q) ?? false)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(activeLeads.count)", label: "Active Leads", icon: "person.crop.circle.badge.plus", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(unassignedCount)", label: "Unassigned", icon: "person.crop.circle.badge.questionmark", color: AVIATheme.warning)
                AdminMetricCard(value: "\(leads.filter { $0.ownerId == viewModel.currentUser.id && !$0.isConverted }.count)", label: "Mine", icon: "person.fill", color: AVIATheme.success)
            }
            .fixedSize(horizontal: false, vertical: true)

            Button { showAddLead = true } label: {
                AdminQuickActionContent(icon: "plus.circle.fill", label: "Add Lead", color: AVIATheme.timelessBrown)
            }
            .buttonStyle(.pressable(.subtle))

            ownerFilterRow
            sourceFilterRow

            if isLoading && leads.isEmpty {
                ProgressView().padding(.vertical, 40)
            } else if leads.isEmpty {
                AdminEmptyState(icon: "person.crop.circle.badge.plus", title: "No leads yet", subtitle: "New enquiries from your website and social media will appear here for triage and assignment.")
            } else if filteredLeads.isEmpty {
                AdminEmptyState(icon: "line.3.horizontal.decrease.circle", title: "No leads match", subtitle: "Try a different filter.")
            } else {
                ForEach(filteredLeads) { lead in
                    NavigationLink(value: lead) {
                        leadCard(lead)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showAddLead) {
            LeadEditSheet(lead: .new(ownerId: viewModel.currentUser.id)) { created in
                leads.insert(created, at: 0)
                Task { await SupabaseService.shared.upsertLead(created) }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Filters

    private var ownerFilterRow: some View {
        Picker("Owner", selection: $ownerFilter) {
            ForEach(OwnerFilter.allCases) { f in
                Text(f.label).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sourceFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(label: "All Sources", icon: nil, isSelected: sourceFilter == nil) { sourceFilter = nil }
                ForEach(LeadSource.allCases) { source in
                    pill(label: source.label, icon: source.icon, isSelected: sourceFilter == source) {
                        sourceFilter = (sourceFilter == source) ? nil : source
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func pill(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.neueCaption2) }
                Text(label).font(.neueCaption2Medium)
            }
            .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background { if isSelected { AVIATheme.timelessBrown } else { AVIATheme.cardBackground } }
            .clipShape(.capsule)
            .overlay { Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: isSelected ? 0 : 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lead card

    private func ownerName(_ lead: Lead) -> String? {
        guard let id = lead.ownerId else { return nil }
        guard let staff = viewModel.allRegisteredUsers.first(where: { $0.id == id }) else { return nil }
        return staff.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? staff.email : staff.fullName
    }

    private func statusColor(_ status: LeadStatus) -> Color {
        switch status {
        case .won: return AVIATheme.success
        case .lost: return AVIATheme.textTertiary
        case .new: return AVIATheme.warning
        default: return AVIATheme.timelessBrown
        }
    }

    private func leadCard(_ lead: Lead) -> some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(lead.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 42, height: 42)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lead.name.isEmpty ? "Unnamed lead" : lead.name)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        HStack(spacing: 5) {
                            Image(systemName: lead.source.icon).font(.neueCaption2)
                            Text(lead.source.label).font(.neueCaption2)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: lead.status.icon).font(.neueCaption2)
                            Text(lead.status.label).font(.neueCaption2Medium)
                        }
                        .foregroundStyle(statusColor(lead.status))
                        HStack(spacing: 4) {
                            Image(systemName: lead.temperature.icon).font(.neueCaption2)
                            Text(lead.temperature.label).font(.neueCaption2)
                        }
                        .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .padding(14)

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                HStack(spacing: 6) {
                    if let owner = ownerName(lead) {
                        Image(systemName: "person.crop.circle.fill").font(.neueCaption2)
                        Text(owner).font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    } else {
                        Image(systemName: "person.crop.circle.badge.questionmark").font(.neueCaption2)
                        Text("Unassigned").font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.warning)
                    }
                    Spacer()
                    Text(lead.createdAt.formatted(.relative(presentation: .named)))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .foregroundStyle(AVIATheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        leads = await SupabaseService.shared.fetchAllLeads()
        isLoading = false
    }
}
