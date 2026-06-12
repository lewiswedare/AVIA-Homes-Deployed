import SwiftUI
import UIKit
import PhotosUI
import Supabase

@Observable
class ImageUploadService {
    static let shared = ImageUploadService()

    private let bucketName = "catalog-images"
    private var client: SupabaseClient { SupabaseService.shared.client }

    var isUploading = false

    func uploadImage(_ data: Data, folder: String, fileName: String) async -> String? {
        await uploadFile(data, folder: folder, fileName: fileName, contentType: "image/jpeg")
    }

    func uploadFile(_ data: Data, folder: String, fileName: String, contentType: String) async -> String? {
        isUploading = true
        defer { isUploading = false }

        let path = "\(folder)/\(fileName)"

        do {
            try await client.storage
                .from(bucketName)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: true
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

    func loadTransferable(from item: PhotosPickerItem) async -> Data? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        guard let uiImage = UIImage(data: data) else { return nil }
        return Self.downscaledJPEG(uiImage)
    }

    /// Downscales to a sensible upload size and re-encodes as JPEG.
    /// Photos were previously re-encoded as full-resolution PNGs, ballooning
    /// uploads 5–10× and slowing every image-heavy screen that fetched them.
    static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else {
            return image.jpegData(compressionQuality: quality)
        }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
