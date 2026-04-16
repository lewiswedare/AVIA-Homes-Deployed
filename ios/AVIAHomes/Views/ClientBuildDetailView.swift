import SwiftUI

struct ClientBuildDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let build: ClientBuild
    @State private var selectedSection: DetailSection = .overview
    @State private var expandedStage: String?

    enum DetailSection: String, CaseIterable {
        case overview = "Overview"
        case progress = "Progress"
        case specs = "Specs"
        case colours = "Colours"
        case documents = "Documents"
        case requests = "Requests"

        var icon: String {
            switch self {
            case .overview: "house.fill"
            case .progress: "chart.bar.fill"
            case .specs: "checklist"
            case .colours: "paintpalette.fill"
            case .documents: "doc.text.fill"
            case .requests: "bubble.left.and.bubble.right.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                clientHeader
                sectionPicker
                sectionContent
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle(build.clientDisplayName)
        .navigationBarTitleDisplayMode(.large)
    }

    private var clientHeader: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 52, height: 52)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(build.clientDisplayName)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        if build.additionalClients.isEmpty {
                            Text(build.client.email)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        } else {
                            Text("\(build.allClients.count) clients assigned")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    Spacer()
                }

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                HStack(spacing: 0) {
                    detailMetric(label: "Design", value: build.homeDesign)
                    detailMetric(label: "Lot", value: build.lotNumber)
                    detailMetric(label: "Estate", value: build.estate.components(separatedBy: ",").first ?? build.estate)
                }

                HStack(spacing: 0) {
                    detailMetric(label: "Contract", value: build.contractDate.formatted(date: .abbreviated, time: .omitted))
                    detailMetric(label: "Progress", value: "\(Int(build.overallProgress * 100))%")
                    detailMetric(label: "Stage", value: build.statusLabel)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 6)
                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * build.overallProgress), height: 6)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 10) {
                    if let phone = URL(string: "tel:\(build.client.phone.replacingOccurrences(of: " ", with: ""))") {
                        Link(destination: phone) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.neueCorp(11))
                                Text("Call")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    if let email = URL(string: "mailto:\(build.client.email)") {
                        Link(destination: email) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.neueCorp(11))
                                Text("Email")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func detailMetric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(DetailSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.neueCorp(10))
                            Text(section.rawValue)
                                .font(.neueCaptionMedium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedSection == section ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                        .background(selectedSection == section ? AVIATheme.cardBackgroundAlt : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if selectedSection == section {
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

    private var isAdmin: Bool {
        appViewModel.currentRole.isAnyStaffRole
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .progress:
            progressSection
        case .specs:
            if isAdmin {
                AdminBuildSpecReviewView(buildId: build.id, clientName: build.clientDisplayName, clientId: build.client.id)
            } else {
                ClientSpecConfirmationView(buildId: build.id)
            }
        case .colours:
            BuildColourSelectionView(buildId: build.id)
        case .documents:
            DocumentsView()
        case .requests:
            RequestsView()
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Build Summary")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }

                    VStack(spacing: 8) {
                        infoRow(label: "Home Design", value: build.homeDesign)
                        infoRow(label: "Lot Number", value: build.lotNumber)
                        infoRow(label: "Estate", value: build.estate)
                        infoRow(label: "Contract Date", value: build.contractDate.formatted(date: .long, time: .omitted))
                        infoRow(label: "Current Stage", value: build.statusLabel)
                        infoRow(label: "Overall Progress", value: "\(Int(build.overallProgress * 100))%")
                    }
                }
                .padding(16)
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Client Contact")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }

                    VStack(spacing: 8) {
                        ForEach(build.allClients, id: \.id) { clientUser in
                            if build.allClients.count > 1 {
                                Text(clientUser.fullName)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            infoRow(label: "Name", value: clientUser.fullName)
                            infoRow(label: "Email", value: clientUser.email)
                            infoRow(label: "Phone", value: clientUser.phone)
                            if clientUser.id != build.allClients.last?.id {
                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(build.buildStages.enumerated()), id: \.element.id) { index, stage in
                TimelineStageRow(
                    stage: stage,
                    isFirst: index == 0,
                    isLast: index == build.buildStages.count - 1,
                    isExpanded: expandedStage == stage.id
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        expandedStage = expandedStage == stage.id ? nil : stage.id
                    }
                }
            }
        }
    }

}

extension ClientBuild: Hashable {
    nonisolated static func == (lhs: ClientBuild, rhs: ClientBuild) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
