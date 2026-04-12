import SwiftUI
import PhotosUI

struct AdminImagePickerField: View {
    let label: String
    @Binding var imageURL: String
    let folder: String
    var itemId: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var previewImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)

            if !imageURL.isEmpty {
                imagePreview
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 6) {
                        if isUploading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "photo.badge.plus")
                        }
                        Text(isUploading ? "Uploading..." : (imageURL.isEmpty ? "Choose Image" : "Replace Image"))
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isUploading ? AVIATheme.textTertiary : AVIATheme.teal)
                    .clipShape(Capsule())
                }
                .disabled(isUploading)

                if !imageURL.isEmpty {
                    Button {
                        withAnimation { imageURL = "" }
                        previewImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AVIATheme.destructive.opacity(0.7))
                    }
                }

                Spacer()
            }

            TextField("Or paste URL...", text: $imageURL)
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
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleImageSelection(newItem) }
        }
    }

    private var imagePreview: some View {
        Group {
            if let previewImage {
                Color(.secondarySystemBackground)
                    .frame(height: 120)
                    .overlay {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                Color(.secondarySystemBackground)
                    .frame(height: 120)
                    .overlay {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            } else {
                                ProgressView()
                                    .tint(AVIATheme.teal)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private func handleImageSelection(_ item: PhotosPickerItem) async {
        isUploading = true
        uploadError = nil

        guard let data = await ImageUploadService.shared.loadTransferable(from: item) else {
            uploadError = "Failed to load image"
            isUploading = false
            return
        }

        if let uiImg = UIImage(data: data) {
            previewImage = uiImg
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = itemId.isEmpty ? "image" : itemId.replacingOccurrences(of: " ", with: "_").lowercased()
        let fileName = "\(safeName)_\(timestamp).png"

        if let url = await ImageUploadService.shared.uploadImage(data, folder: folder, fileName: fileName) {
            imageURL = url
            uploadError = nil
        } else {
            uploadError = "Upload failed. Check storage bucket setup."
        }

        isUploading = false
        selectedItem = nil
    }
}

struct AdminCompactImagePicker: View {
    @Binding var imageURL: String
    let folder: String
    var itemId: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false

    var body: some View {
        HStack(spacing: 6) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 4) {
                    if isUploading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(AVIATheme.teal)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 10))
                    }
                    Text(isUploading ? "..." : "Upload")
                        .font(.neueCaption2)
                }
                .foregroundStyle(AVIATheme.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AVIATheme.teal.opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isUploading)

            TextField("Image URL (optional)", text: $imageURL)
                .font(.neueCaption2)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleSelection(newItem) }
        }
    }

    private func handleSelection(_ item: PhotosPickerItem) async {
        isUploading = true

        guard let data = await ImageUploadService.shared.loadTransferable(from: item) else {
            isUploading = false
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = itemId.isEmpty ? "image" : itemId.replacingOccurrences(of: " ", with: "_").lowercased()
        let fileName = "\(safeName)_\(timestamp).png"

        if let url = await ImageUploadService.shared.uploadImage(data, folder: folder, fileName: fileName) {
            imageURL = url
        }

        isUploading = false
        selectedItem = nil
    }
}
