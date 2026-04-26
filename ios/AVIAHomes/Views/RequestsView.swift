import SwiftUI
import PhotosUI

struct RequestsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedFilter: RequestStatus?
    @State private var showNewRequest = false
    @State private var selectedRequest: ServiceRequest?

    private var filteredRequests: [ServiceRequest] {
        var reqs = viewModel.requests
        if let filter = selectedFilter {
            reqs = reqs.filter { $0.status == filter }
        }
        return reqs.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterSection

                if viewModel.requests.isEmpty {
                    ContentUnavailableView(
                        "No Requests",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Submit a request and we'll get back to you.")
                    )
                    .foregroundStyle(AVIATheme.textSecondary)
                    .padding(.top, 40)
                } else {
                    BentoCard(cornerRadius: 13) {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredRequests.enumerated()), id: \.element.id) { index, request in
                                Button { selectedRequest = request } label: {
                                    RequestRow(request: request)
                                }
                                .buttonStyle(.pressable(.subtle))
                                if index < filteredRequests.count - 1 {
                                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 64)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Request", systemImage: "plus.circle.fill") {
                    showNewRequest = true
                }
                .tint(AVIATheme.timelessBrown)
            }
        }
        .sheet(isPresented: $showNewRequest) {
            NewRequestView()
        }
        .sheet(item: $selectedRequest) { request in
            RequestDetailView(request: request)
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(RequestStatus.allCases, id: \.self) { status in
                    FilterChip(title: status.rawValue, isSelected: selectedFilter == status) {
                        selectedFilter = selectedFilter == status ? nil : status
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }
}

struct RequestRow: View {
    let request: ServiceRequest

    private var statusColor: Color {
        switch request.status {
        case .open: AVIATheme.warning
        case .inProgress: AVIATheme.timelessBrown
        case .resolved: AVIATheme.success
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            BentoIconCircle(icon: request.category.icon, color: statusColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(request.title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    StatusBadge(title: request.status.rawValue, color: statusColor)
                    Text(request.lastUpdated.formatted(date: .abbreviated, time: .omitted))
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            Spacer()
            if !request.responses.isEmpty {
                Image(systemName: "bubble.left.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RequestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let request: ServiceRequest
    @State private var selectedPhoto: UIImage?

    private var photos: [UIImage] {
        request.attachedPhotos.compactMap { UIImage(data: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BentoCard(cornerRadius: 13) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(request.category.rawValue, systemImage: request.category.icon)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Spacer()
                                let color: Color = switch request.status {
                                case .open: AVIATheme.warning
                                case .inProgress: AVIATheme.timelessBrown
                                case .resolved: AVIATheme.success
                                }
                                StatusBadge(title: request.status.rawValue, color: color)
                            }
                            Text(request.title)
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Submitted \(request.dateCreated.formatted(date: .long, time: .shortened))")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(18)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(request.description)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !photos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Attached Photos")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(Array(photos.enumerated()), id: \.offset) { _, photo in
                                        Button {
                                            selectedPhoto = photo
                                        } label: {
                                            Color.clear
                                                .frame(width: 120, height: 120)
                                                .overlay {
                                                    Image(uiImage: photo)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .allowsHitTesting(false)
                                                }
                                                .clipShape(.rect(cornerRadius: 10))
                                        }
                                        .buttonStyle(.pressable(.subtle))
                                    }
                                }
                            }
                            .contentMargins(.horizontal, 0)
                            .scrollIndicators(.hidden)
                        }
                    }

                    if !request.responses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Responses")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            ForEach(request.responses) { response in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(response.author)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Text(response.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    Text(response.message)
                                        .font(.neueSubheadline)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                }
                                .padding(14)
                                .background(response.isFromClient ? AVIATheme.timelessBrown.opacity(0.08) : AVIATheme.cardBackground)
                                .clipShape(.rect(cornerRadius: 11))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoPreviewOverlay(image: photo)
            }
        }
        .presentationBackground(AVIATheme.background)
    }
}

struct CameraPickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerRepresentable
        init(_ parent: CameraPickerRepresentable) { self.parent = parent }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            Task { @MainActor in
                parent.image = img
                parent.dismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                parent.dismiss()
            }
        }
    }
}

struct NewRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel
    @State private var title = ""
    @State private var description = ""
    @State private var category: RequestCategory = .general
    @State private var attachedImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var showAttachOptions = false
    @State private var fullScreenImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    categorySection
                    detailsSection
                    photosSection
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let photoData = attachedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                        viewModel.submitRequest(title: title, description: description, category: category, photos: photoData)
                        dismiss()
                    }
                    .font(.neueSubheadlineMedium)
                    .tint(AVIATheme.timelessBrown)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .confirmationDialog("Attach Photo", isPresented: $showAttachOptions, titleVisibility: .visible) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                    Text("Choose from Library")
                }
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            withAnimation(.spring(duration: 0.3)) {
                                attachedImages.append(uiImage)
                            }
                        }
                    }
                    selectedPhotoItems.removeAll()
                }
            }
            .onChange(of: cameraImage) { _, newImage in
                if let newImage {
                    withAnimation(.spring(duration: 0.3)) {
                        attachedImages.append(newImage)
                    }
                    cameraImage = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerRepresentable(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .fullScreenCover(item: $fullScreenImage) { image in
                PhotoPreviewOverlay(image: image)
            }
        }
        .presentationBackground(AVIATheme.background)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(RequestCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.neueCaption)
                                Text(cat.rawValue)
                                    .font(.neueCaptionMedium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if category == cat {
                                    Capsule().fill(AVIATheme.timelessBrown)
                                } else {
                                    Capsule().fill(AVIATheme.cardBackground)
                                }
                            }
                            .foregroundStyle(category == cat ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                            .overlay {
                                if category != cat {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                            }
                        }
                        .buttonStyle(.pressable(.subtle))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)

            TextField("Subject", text: $title)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .tint(AVIATheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }

            TextField("Describe your request...", text: $description, axis: .vertical)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .tint(AVIATheme.textPrimary)
                .lineLimit(4...8)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)

            if !attachedImages.isEmpty {
                photoThumbnails
            }

            addPhotosButton
        }
    }

    private var photoThumbnails: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, image in
                    photoThumbnail(image: image, index: index)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                fullScreenImage = image
            } label: {
                Color.clear
                    .frame(width: 90, height: 90)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.pressable(.subtle))

            Button {
                removeImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AVIATheme.aviaWhite, AVIATheme.aviaBlack.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
    }

    private func removeImage(at index: Int) {
        withAnimation(.spring(duration: 0.25)) {
            let _ = attachedImages.remove(at: index)
        }
    }

    private var addPhotosButton: some View {
        Button {
            showAttachOptions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.neueSubheadline)
                Text(attachedImages.isEmpty ? "Add Photos" : "Add More")
                    .font(.neueSubheadlineMedium)
            }
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AVIATheme.timelessBrown.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AVIATheme.timelessBrown.opacity(0.25), lineWidth: 1)
            }
        }
    }
}

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

struct PhotoPreviewOverlay: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AVIATheme.aviaBlack)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .tint(AVIATheme.aviaWhite)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
