import SwiftUI
import UniformTypeIdentifiers

struct AdminPDFPickerField: View {
    let label: String
    @Binding var pdfURL: String
    let folder: String
    var itemId: String = ""

    @State private var isPickerPresented = false
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)

            if !pdfURL.isEmpty {
                pdfPreview
            }

            HStack(spacing: 10) {
                Button {
                    isPickerPresented = true
                } label: {
                    HStack(spacing: 6) {
                        if isUploading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AVIATheme.aviaWhite)
                        } else {
                            Image(systemName: "doc.badge.plus")
                        }
                        Text(isUploading ? "Uploading..." : (pdfURL.isEmpty ? "Choose PDF" : "Replace PDF"))
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isUploading ? AVIATheme.textTertiary : AVIATheme.timelessBrown)
                    .clipShape(Capsule())
                }
                .disabled(isUploading)

                if !pdfURL.isEmpty {
                    Button {
                        withAnimation { pdfURL = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AVIATheme.destructive.opacity(0.7))
                    }
                }

                Spacer()
            }

            TextField("Or paste URL...", text: $pdfURL)
                .font(.neueCaption2)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 8))

            if let uploadError {
                Text(uploadError)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.destructive)
            }
        }
        .padding(.horizontal, 14)
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.pdf]
        ) { result in
            switch result {
            case .success(let url):
                Task { await handlePDFSelection(url) }
            case .failure(let error):
                uploadError = error.localizedDescription
            }
        }
    }

    private var pdfPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 44, height: 44)
                .background(AVIATheme.timelessBrown.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("PDF uploaded")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(pdfURL)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func handlePDFSelection(_ url: URL) async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            uploadError = "Failed to read PDF"
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = itemId.isEmpty ? "document" : itemId.replacingOccurrences(of: " ", with: "_").lowercased()
        let fileName = "\(safeName)_\(timestamp).pdf"

        if let publicURL = await ImageUploadService.shared.uploadFile(
            data,
            folder: folder,
            fileName: fileName,
            contentType: "application/pdf"
        ) {
            pdfURL = publicURL
        } else {
            uploadError = "Upload failed. Check storage bucket setup."
        }
    }
}
