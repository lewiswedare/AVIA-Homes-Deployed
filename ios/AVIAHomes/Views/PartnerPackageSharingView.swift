import SwiftUI

struct PartnerPackageSharingView: View {
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection = 0
    @State private var showShareConfirmation = false
    @State private var pendingClientId: String?
    @State private var showCopiedLink = false

    private var sharedClientIds: [String] {
        viewModel.partnerSharedClientsForPackage(package.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                packageHeader

                Picker("Section", selection: $selectedSection) {
                    Text("Share with Clients").tag(0)
                    Text("Client Responses").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedSection {
                        case 0: clientSharingSection
                        case 1: responsesSection
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .presentationContentInteraction(.scrolls)
            }
            .background(AVIATheme.background)
            .navigationTitle("Share Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.teal)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .overlay(alignment: .bottom) {
            if showCopiedLink {
                linkCopiedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Share Package", isPresented: $showShareConfirmation) {
            Button("Cancel", role: .cancel) { pendingClientId = nil }
            Button("Share") {
                if let clientId = pendingClientId {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.partnerSharePackageWithClient(packageId: package.id, clientId: clientId)
                    }
                }
                pendingClientId = nil
            }
        } message: {
            if let clientId = pendingClientId {
                let client = viewModel.clientUsers.first { $0.id == clientId }
                Text("Send \(package.title) to \(client?.fullName ?? "this client") for review?")
            }
        }
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
                        .foregroundStyle(AVIATheme.teal)
                    Text("•")
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(package.estate)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }
            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    showCopiedLink = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.spring(response: 0.3)) {
                        showCopiedLink = false
                    }
                }
            } label: {
                Image(systemName: "link")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.teal)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.teal.opacity(0.1))
                    .clipShape(Circle())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showCopiedLink)
        }
        .padding(16)
    }

    private var clientSharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SELECT CLIENTS")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                Text("\(sharedClientIds.count) shared")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.teal)
            }

            let clients = viewModel.clientUsers
            let uniqueClients = Dictionary(grouping: clients, by: \.id).compactMap(\.value.first)

            ForEach(uniqueClients, id: \.id) { client in
                let isShared = sharedClientIds.contains(client.id)

                Button {
                    if isShared {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.partnerRemoveClientFromPackage(packageId: package.id, clientId: client.id)
                        }
                    } else {
                        pendingClientId = client.id
                        showShareConfirmation = true
                    }
                } label: {
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Text(client.initials.isEmpty ? "?" : client.initials)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(AVIATheme.tealGradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                if isShared {
                                    let response = viewModel.clientResponseForPackage(package.id, clientId: client.id)
                                    HStack(spacing: 4) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 8))
                                        Text(response?.status.rawValue ?? "Shared")
                                    }
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
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AVIATheme.teal)
                            } else {
                                Image(systemName: "paperplane.circle")
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
                    Text("No clients registered yet")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text("Clients will appear here once they sign up")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .multilineTextAlignment(.center)
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

    private var linkCopiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "link.badge.plus")
                .font(.neueSubheadlineMedium)
            Text("Share link copied")
                .font(.neueSubheadlineMedium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AVIATheme.tealGradient)
        .clipShape(Capsule())
        .shadow(color: AVIATheme.teal.opacity(0.3), radius: 8, y: 4)
        .padding(.bottom, 20)
    }

    private func responseColor(_ status: PackageResponseStatus?) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .accepted: AVIATheme.success
        case .declined: AVIATheme.destructive
        case nil: AVIATheme.teal
        }
    }
}
