import SwiftUI
import UniformTypeIdentifiers
import Supabase

// NOTE: The "documents" Supabase storage bucket must be created manually
// in the Supabase dashboard with public read access before uploads will work.

@Observable
class PDFUploadService {
    static let shared = PDFUploadService()

    var isUploading = false
    var uploadProgress: Double = 0

    private let bucketName = "documents"
    private var client: SupabaseClient { SupabaseService.shared.client }

    func uploadPDF(_ data: Data, fileName: String, buildId: String) async -> String? {
        isUploading = true
        uploadProgress = 0
        defer { isUploading = false }

        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let path = "\(buildId)/\(UUID().uuidString)_\(safeName)"

        do {
            try await client.storage
                .from(bucketName)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "application/pdf",
                        upsert: false
                    )
                )

            let publicURL = try client.storage
                .from(bucketName)
                .getPublicURL(path: path)

            uploadProgress = 1.0
            return publicURL.absoluteString
        } catch {
            print("[PDFUploadService] Upload failed: \(error)")
            return nil
        }
    }

    func deletePDF(fileURL: String, buildId: String) async {
        guard let url = URL(string: fileURL),
              let pathComponent = url.pathComponents.last else { return }
        let path = "\(buildId)/\(pathComponent)"
        _ = try? await client.storage
            .from(bucketName)
            .remove(paths: [path])
    }
}
