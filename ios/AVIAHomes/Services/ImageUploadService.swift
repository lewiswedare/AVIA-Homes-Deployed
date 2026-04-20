import SwiftUI
import PhotosUI
import Supabase

@Observable
class ImageUploadService {
    static let shared = ImageUploadService()

    private let bucketName = "catalog-images"
    private var client: SupabaseClient { SupabaseService.shared.client }

    var isUploading = false

    func uploadImage(_ data: Data, folder: String, fileName: String) async -> String? {
        await uploadFile(data, folder: folder, fileName: fileName, contentType: "image/png")
    }

    func uploadFile(_ data: Data, folder: String, fileName: String, contentType: String) async -> String? {
        isUploading = true
        defer { isUploading = false }

        let uniqueFileName = uniquify(fileName: fileName)
        let path = "\(folder)/\(uniqueFileName)"

        do {
            try await client.storage
                .from(bucketName)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: false
                    )
                )

            let publicURL = try client.storage
                .from(bucketName)
                .getPublicURL(path: path)

            return publicURL.absoluteString
        } catch {
            print("[ImageUploadService] Upload failed: \(error)")
            return nil
        }
    }

    private func uniquify(fileName: String) -> String {
        let uuid = UUID().uuidString
        let ext = (fileName as NSString).pathExtension
        return ext.isEmpty ? uuid : "\(uuid).\(ext)"
    }

    func loadTransferable(from item: PhotosPickerItem) async -> Data? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.pngData()
    }
}
