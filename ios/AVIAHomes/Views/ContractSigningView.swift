import SwiftUI
import PDFKit
import PencilKit

struct ContractSigningView: View {
    let contract: ContractSignatureRow
    let assignment: PackageAssignment
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var signerName = ""
    @State private var isSigning = false
    @State private var canvasView = PKCanvasView()
    @State private var hasDrawn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        contractHeader
                        pdfSection
                        signatureSection
                        legalText
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
                signButton
            }
            .background(AVIATheme.background)
            .navigationTitle("Sign Contract")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .onAppear {
                signerName = viewModel.currentUser.fullName
            }
        }
    }

    // MARK: - Contract Header

    private var contractHeader: some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AVIATheme.timelessBrown)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Contract for \(package.title)")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Lot \(package.lotNumber) — \(package.location)")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - PDF Section

    private var pdfSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Contract Document")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }

            if let urlString = contract.contract_document_url, let url = URL(string: urlString) {
                PDFKitView(url: url)
                    .frame(height: 400)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
            } else {
                BentoCard(cornerRadius: 12) {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("Contract document not available")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Signature Section

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "signature")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Your Signature")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                Spacer()
                Button {
                    canvasView.drawing = PKDrawing()
                    hasDrawn = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.neueCaption2)
                        Text("Clear")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.destructive)
                }
            }

            SignatureCanvasView(canvasView: $canvasView, hasDrawn: $hasDrawn)
                .frame(height: 150)
                .background(AVIATheme.aviaWhite)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Full Name")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textSecondary)
                TextField("Your full name", text: $signerName)
                    .font(.neueSubheadline)
                    .padding(12)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
            }
        }
    }

    // MARK: - Legal Text

    private var legalText: some View {
        BentoCard(cornerRadius: 12) {
            Text("By signing below, I \(signerName.isEmpty ? "[name]" : signerName) confirm that I have read and agree to the terms of this contract.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .padding(16)
        }
    }

    // MARK: - Sign Button

    private var signButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await signContract() }
            } label: {
                HStack(spacing: 8) {
                    if isSigning {
                        ProgressView()
                            .tint(AVIATheme.aviaWhite)
                    } else {
                        Image(systemName: "signature")
                            .font(.neueSubheadlineMedium)
                    }
                    Text("Sign Contract")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(AVIATheme.aviaWhite)
                .background(canSign ? AVIATheme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!canSign || isSigning)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AVIATheme.cardBackground)
    }

    private var canSign: Bool {
        hasDrawn && !signerName.isEmpty
    }

    private func signContract() async {
        isSigning = true
        defer { isSigning = false }

        let image = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: UIScreen.main.scale)
        guard let pngData = image.pngData() else { return }

        let success = await SupabaseService.shared.signContract(
            contractId: contract.id,
            assignmentId: assignment.id,
            signatureImageData: pngData,
            signerName: signerName
        )
        guard success else { return }

        // Notify admins
        var recipientIdSet = Set<String>()
        for user in viewModel.allRegisteredUsers where user.role.isAnyStaffRole {
            recipientIdSet.insert(user.id)
        }
        for user in viewModel.allRegisteredUsers where user.role == .admin {
            recipientIdSet.insert(user.id)
        }
        recipientIdSet.remove(viewModel.currentUser.id)
        for recipientId in recipientIdSet {
            await viewModel.notificationService.createNotification(
                recipientId: recipientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .contractSigned,
                title: "Contract Signed",
                message: "\(viewModel.currentUser.fullName) signed the contract for \(package.title)",
                referenceId: package.id,
                referenceType: "package"
            )
        }

        dismiss()
    }
}

// MARK: - PDF Kit View

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Signature Canvas

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var hasDrawn: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1), width: 3)
        canvasView.backgroundColor = UIColor(red: 225/255, green: 221/255, blue: 220/255, alpha: 1)
        canvasView.isOpaque = true
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(hasDrawn: $hasDrawn)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasDrawn: Bool

        init(hasDrawn: Binding<Bool>) {
            _hasDrawn = hasDrawn
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasDrawn = !canvasView.drawing.strokes.isEmpty
        }
    }
}
