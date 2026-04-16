import SwiftUI
import PencilKit

struct MyDesignPlanView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DesignPlanViewModel()
    @State private var selectedSection: PlanSection = .floorplan
    @State private var showMarkup: Bool = false
    @State private var showConfirmAlert: Bool = false

    enum PlanSection: String, CaseIterable {
        case floorplan = "Floor Plan"
        case correspondence = "Messages"
        case documents = "Documents"

        var icon: String {
            switch self {
            case .floorplan: "rectangle.split.2x2"
            case .correspondence: "bubble.left.and.bubble.right.fill"
            case .documents: "doc.text.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                floorplanHero
                VStack(spacing: 16) {
                    statusHeader
                    sectionPicker
                    sectionContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle(appViewModel.currentUser.homeDesign)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showMarkup) {
            FloorplanMarkupView(
                drawing: $viewModel.markupDrawing,
                floorplanURL: viewModel.floorplanImageURL,
                onSubmit: { viewModel.submitMarkup() }
            )
        }
        .alert("Confirm Plans", isPresented: $showConfirmAlert) {
            Button("Confirm", role: .destructive) {
                viewModel.confirmPlan()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("By confirming, you approve the current floor plan and it will proceed to final build documentation. This cannot be undone.")
        }
        .sensoryFeedback(.success, trigger: viewModel.showMarkupSubmitted)
    }

    private var floorplanHero: some View {
        AVIATheme.timelessBrown
            .frame(height: 280)
            .overlay {
                AsyncImage(url: URL(string: viewModel.floorplanImageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit).padding(12)
                    } else if phase.error != nil {
                        Image(systemName: "rectangle.split.2x2")
                            .font(.system(size: 48))
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.3))
                    } else {
                        ProgressView().tint(AVIATheme.aviaWhite.opacity(0.6))
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showMarkup = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.neueCaptionMedium)
                        Text("Markup")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(Capsule())
                }
                .padding(16)
            }
            .clipShape(.rect(cornerRadius: 0))
    }

    private var statusHeader: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PLAN STATUS")
                            .font(.neueCaption2Medium)
                            .kerning(1.2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(viewModel.planStatus.rawValue)
                            .font(.neueCorpMedium(22))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: viewModel.planStatus.icon)
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(statusColor)
                        .frame(width: 44, height: 44)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Circle())
                }

                HStack(spacing: 8) {
                    confirmationBadge(label: "Client", confirmed: viewModel.clientConfirmed)
                    confirmationBadge(label: "AVIA", confirmed: viewModel.aviaConfirmed)
                }

                if !viewModel.isFinalised && viewModel.planStatus != .inReview {
                    HStack(spacing: 10) {
                        Button {
                            showMarkup = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw.fill")
                                    .font(.neueCorp(12))
                                Text("Mark Up Plans")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }

                        Button {
                            showConfirmAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.neueCorp(12))
                                Text("Confirm Plans")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }

                if viewModel.isFinalised {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AVIATheme.success)
                        Text("Plans confirmed and finalised")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.success)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(AVIATheme.success.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .padding(16)
        }
    }

    private func confirmationBadge(label: String, confirmed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "circle.dashed")
                .font(.neueCorp(12))
                .foregroundStyle(confirmed ? AVIATheme.success : AVIATheme.textTertiary)
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(confirmed ? AVIATheme.textPrimary : AVIATheme.textTertiary)
            if confirmed {
                Text("Confirmed")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.success)
            } else {
                Text("Pending")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(confirmed ? AVIATheme.success.opacity(0.05) : AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch viewModel.planStatus {
        case .draft: AVIATheme.textTertiary
        case .inReview: AVIATheme.timelessBrownLight
        case .changesRequested: AVIATheme.warning
        case .approved: AVIATheme.success
        case .finalised: AVIATheme.timelessBrown
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(PlanSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: section.icon)
                            .font(.neueCorp(11))
                        Text(section.rawValue)
                            .font(.neueCaptionMedium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
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
            Spacer()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .floorplan:
            floorplanSection
        case .correspondence:
            correspondenceSection
        case .documents:
            documentsSection
        }
    }

    // MARK: - Floorplan

    private var floorplanSection: some View {
        VStack(spacing: 14) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.currentUser.homeDesign)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(appViewModel.currentUser.lotNumber)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        Text("v3")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AVIATheme.timelessBrown.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                    VStack(spacing: 8) {
                        floorplanInfoRow(label: "Design", value: appViewModel.currentUser.homeDesign)
                        floorplanInfoRow(label: "Revision", value: "Version 3 — Updated")
                        floorplanInfoRow(label: "Last Modified", value: Date().addingTimeInterval(-14 * 86400).formatted(date: .abbreviated, time: .omitted))
                        floorplanInfoRow(label: "Changes", value: "Alfresco extended, pantry relocated, ensuite niche")
                    }
                }
                .padding(16)
            }

            if viewModel.hasUnsavedMarkup || !viewModel.markupDrawing.strokes.isEmpty {
                BentoCard(cornerRadius: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.draw.fill")
                            .font(.neueCorpMedium(16))
                            .foregroundStyle(AVIATheme.warning)
                            .frame(width: 36, height: 36)
                            .background(AVIATheme.warning.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Markup Annotations")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(viewModel.showMarkupSubmitted ? "Submitted for review" : "Unsaved annotations on plan")
                                .font(.neueCaption)
                                .foregroundStyle(viewModel.showMarkupSubmitted ? AVIATheme.success : AVIATheme.warning)
                        }
                        Spacer()
                        Button {
                            showMarkup = true
                        } label: {
                            Text("Edit")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func floorplanInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }

    // MARK: - Correspondence

    private var correspondenceSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.correspondence) { msg in
                correspondenceCard(msg)
            }

            messageComposer
        }
    }

    private func correspondenceCard(_ msg: PlanCorrespondence) -> some View {
        let isClient = msg.sender == .client
        return HStack(alignment: .top, spacing: 10) {
            if isClient { Spacer(minLength: 40) }

            VStack(alignment: isClient ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if !isClient {
                        senderAvatar(msg.senderName, isAvia: true)
                    }
                    VStack(alignment: isClient ? .trailing : .leading, spacing: 1) {
                        Text(msg.senderName)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(msg.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    if isClient {
                        senderAvatar(msg.senderName, isAvia: false)
                    }
                }

                Text(msg.message)
                    .font(.neueCaption)
                    .foregroundStyle(isClient ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(isClient ? .trailing : .leading)
                    .padding(12)
                    .background(isClient ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))

                if let attachment = msg.attachmentName {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.neueCorp(10))
                        Text(attachment)
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AVIATheme.timelessBrown.opacity(0.06))
                    .clipShape(Capsule())
                }
            }

            if !isClient { Spacer(minLength: 40) }
        }
    }

    private func senderAvatar(_ name: String, isAvia: Bool) -> some View {
        let initials = name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
        return Text(initials)
            .font(.neueCaption2Medium)
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(width: 28, height: 28)
            .background(isAvia ? AVIATheme.primaryGradient : LinearGradient(colors: [AVIATheme.timelessBrownLight, AVIATheme.timelessBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
    }

    private var messageComposer: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Send a Message")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                }

                TextField("Describe changes or ask a question...", text: $viewModel.newMessageText, axis: .vertical)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .tint(AVIATheme.textPrimary)
                    .lineLimit(3...6)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 10))

                HStack {
                    Spacer()
                    Button {
                        viewModel.sendMessage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.neueCorp(11))
                            Text("Send")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LinearGradient(colors: [AVIATheme.textTertiary], startPoint: .leading, endPoint: .trailing) : AVIATheme.primaryGradient)
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(spacing: 16) {
            if viewModel.isFinalised {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Final Documents")
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.finalDocuments.enumerated()), id: \.element.id) { index, doc in
                                planDocumentRow(doc)
                                if index < viewModel.finalDocuments.count - 1 {
                                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(viewModel.isFinalised ? AVIATheme.textTertiary : AVIATheme.timelessBrown)
                    Text(viewModel.isFinalised ? "Working Documents" : "Plan Documents")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.textPrimary)
                }

                BentoCard(cornerRadius: 14) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.planDocuments.enumerated()), id: \.element.id) { index, doc in
                            planDocumentRow(doc)
                            if index < viewModel.planDocuments.count - 1 {
                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
    }

    private func planDocumentRow(_ doc: PlanDocument) -> some View {
        HStack(spacing: 14) {
            Image(systemName: doc.type.icon)
                .font(.neueCorpMedium(14))
                .foregroundStyle(doc.isFinal ? AVIATheme.timelessBrown : AVIATheme.timelessBrownLight)
                .frame(width: 36, height: 36)
                .background((doc.isFinal ? AVIATheme.timelessBrown : AVIATheme.timelessBrownLight).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(doc.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if doc.isFinal {
                        Text("FINAL")
                            .font(.neueCorpMedium(8))
                            .kerning(0.6)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AVIATheme.success)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(doc.version)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("·")
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("·")
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(doc.fileSize)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "arrow.down.circle")
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
