import SwiftUI

struct AdminRequestsSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String
    @Binding var selectedRequest: ServiceRequest?

    private var filteredRequests: [ServiceRequest] {
        var reqs = viewModel.requests
        if !searchText.isEmpty {
            reqs = reqs.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText) ||
                $0.category.rawValue.localizedStandardContains(searchText)
            }
        }
        return reqs.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                requestMetric(label: "Open", count: viewModel.requests.filter { $0.status == .open }.count, color: AVIATheme.warning)
                requestMetric(label: "In Progress", count: viewModel.requests.filter { $0.status == .inProgress }.count, color: AVIATheme.timelessBrown)
                requestMetric(label: "Resolved", count: viewModel.requests.filter { $0.status == .resolved }.count, color: AVIATheme.success)
            }
            .fixedSize(horizontal: false, vertical: true)

            if filteredRequests.isEmpty {
                AdminEmptyState(icon: "bubble.left.and.bubble.right", title: "No requests found", subtitle: "Client requests will appear here")
            } else {
                ForEach(filteredRequests) { request in
                    AdminRequestRow(request: request) {
                        selectedRequest = request
                    }
                }
            }
        }
    }

    private func requestMetric(label: String, count: Int, color: Color) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 6) {
                Text("\(count)")
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(count > 0 ? color : AVIATheme.textTertiary)
                Text(label)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

struct AdminRequestRow: View {
    let request: ServiceRequest
    let onTap: () -> Void

    private var statusColor: Color {
        switch request.status {
        case .open: AVIATheme.warning
        case .inProgress: AVIATheme.timelessBrown
        case .resolved: AVIATheme.success
        }
    }

    var body: some View {
        Button(action: onTap) {
            BentoCard(cornerRadius: 14) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        BentoIconCircle(icon: request.category.icon, color: statusColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(request.title)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(request.category.rawValue)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("·")
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text(request.lastUpdated.formatted(date: .abbreviated, time: .omitted))
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        Spacer()
                        StatusBadge(title: request.status.rawValue, color: statusColor)
                    }
                    .padding(14)

                    if !request.responses.isEmpty {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill")
                                .font(.neueCorp(9))
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text("\(request.responses.count) response\(request.responses.count == 1 ? "" : "s")")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Spacer()
                            if let last = request.responses.last {
                                Text(last.author)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AdminRequestDetailSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let request: ServiceRequest
    @State private var responseText = ""
    @State private var selectedStatus: RequestStatus

    init(request: ServiceRequest) {
        self.request = request
        _selectedStatus = State(initialValue: request.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    requestHeader
                    statusUpdateCard
                    if !request.responses.isEmpty { responsesSection }
                    addResponseCard
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationBackground(AVIATheme.background)
    }

    private var requestHeader: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(request.category.rawValue, systemImage: request.category.icon)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    StatusBadge(title: request.status.rawValue, color: statusColor(request.status))
                }
                Text(request.title)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(request.description)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
                Text("Submitted \(request.dateCreated.formatted(date: .long, time: .shortened))")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(18)
        }
    }

    private var statusUpdateCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Update Status")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                HStack(spacing: 8) {
                    ForEach(RequestStatus.allCases, id: \.self) { status in
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedStatus = status }
                        } label: {
                            Text(status.rawValue)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(selectedStatus == status ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedStatus == status ? statusColor(status) : AVIATheme.cardBackgroundAlt)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Responses")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            ForEach(request.responses) { response in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(response.author)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text(response.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Text(response.message)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(14)
                .background(response.isFromClient ? AVIATheme.timelessBrown.opacity(0.06) : AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var addResponseCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Response")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                TextEditor(text: $responseText)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(AVIATheme.cardBackgroundAlt)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                Button {
                    let trimmed = responseText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await viewModel.respondToRequest(
                            requestId: request.id,
                            responseText: trimmed,
                            newStatus: selectedStatus
                        )
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Send Response")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(responseText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
    }

    private func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .open: AVIATheme.warning
        case .inProgress: AVIATheme.timelessBrown
        case .resolved: AVIATheme.success
        }
    }
}
