import SwiftUI

struct AddClientToBuildSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild
    @State private var searchText = ""

    private var availableClients: [ClientUser] {
        let existingIds = Set(build.allClientIds)
        var clients = viewModel.clientUsers.filter { !existingIds.contains($0.id) }
        if !searchText.isEmpty {
            clients = clients.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }
        return clients.sorted { $0.lastName < $1.lastName }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if availableClients.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(searchText.isEmpty ? "No available clients" : "No matching clients")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Text(searchText.isEmpty ? "All registered clients are already assigned to this build." : "Try a different search term.")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        BentoCard(cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Select a client to add", systemImage: "person.badge.plus")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)

                                ForEach(availableClients, id: \.id) { client in
                                    Button {
                                        viewModel.addClientToBuild(buildId: build.id, clientId: client.id)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(client.initials.isEmpty ? "?" : client.initials)
                                                .font(.neueCorp(11))
                                                .foregroundStyle(AVIATheme.aviaWhite)
                                                .frame(width: 36, height: 36)
                                                .background(AVIATheme.primaryGradient)
                                                .clipShape(Circle())

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                                    .font(.neueCaptionMedium)
                                                    .foregroundStyle(AVIATheme.textPrimary)
                                                Text(client.email)
                                                    .font(.neueCaption2)
                                                    .foregroundStyle(AVIATheme.textTertiary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(AVIATheme.timelessBrown)
                                        }
                                        .padding(10)
                                        .clipShape(.rect(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Add Client")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search clients")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }
}
