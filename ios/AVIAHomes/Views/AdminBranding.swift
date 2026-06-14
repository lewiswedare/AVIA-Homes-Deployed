import SwiftUI
import PhotosUI

// MARK: - Brand Texture

/// Subtle architectural hairline texture for branded banners — thin diagonal
/// lines drawn at low opacity over a dark gradient, evoking premium blueprint
/// paper. Purely decorative; never intercepts touches.
struct AVIABrandTexture: View {
    var tint: Color = AVIATheme.aviaWhite
    var lineOpacity: Double = 0.05
    var spacing: CGFloat = 26

    var body: some View {
        Canvas { context, size in
            let shading = GraphicsContext.Shading.color(tint.opacity(lineOpacity))
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(path, with: shading, lineWidth: 1)
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Reusable branded dark gradient + texture + faded AVIA monogram watermark,
/// used as the backdrop for staff-facing hero banners.
struct AVIABrandBackdrop: View {
    var watermarkWidth: CGFloat = 180
    var watermarkOffset: CGSize = CGSize(width: 104, height: 12)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AVIATheme.timelessBrown, AVIATheme.aviaBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            AVIABrandTexture()
            Image("AVIALogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: watermarkWidth)
                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.05))
                .rotationEffect(.degrees(-8))
                .offset(watermarkOffset)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Workspace Hero Banner

/// The branded staff "command bar" at the top of the admin Workspace. Combines
/// the AVIA wordmark, a personal greeting with the staff member's photo, and a
/// live daily-pulse stat strip — turning a plain greeting box into a branded
/// operating-system header.
struct WorkspaceHeroBanner: View {
    let user: ClientUser
    let dueToday: Int
    let overdue: Int
    let scheduledToday: Int
    let followUps: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let name = user.firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? part : "\(part), \(name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Image("AVIALogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 15)
                    .foregroundStyle(AVIATheme.aviaWhite)
                Spacer()
                Text("STAFF WORKSPACE")
                    .font(.neueCaption2Medium)
                    .tracking(1.8)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.55))
            }

            HStack(spacing: 14) {
                UserAvatarView(user: user, size: 52)
                    .overlay {
                        Circle().stroke(AVIATheme.aviaWhite.opacity(0.45), lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.neueCaption2Medium)
                        .tracking(0.8)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.6))
                    Text(greeting)
                        .font(.neueCorpMedium(25))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
            }

            pulseStrip
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { AVIABrandBackdrop() }
        .clipShape(.rect(cornerRadius: 18))
    }

    private var pulseStrip: some View {
        HStack(spacing: 0) {
            pulseSegment(value: dueToday, label: "Due Today", icon: "checklist")
            pulseDivider
            pulseSegment(value: overdue, label: "Overdue", icon: "exclamationmark.triangle.fill", emphasised: overdue > 0)
            pulseDivider
            pulseSegment(value: scheduledToday, label: "Scheduled", icon: "calendar")
            pulseDivider
            pulseSegment(value: followUps, label: "Follow-ups", icon: "bell.fill")
        }
        .padding(.vertical, 4)
        .background(AVIATheme.aviaWhite.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AVIATheme.aviaWhite.opacity(0.12), lineWidth: 1)
        }
    }

    private var pulseDivider: some View {
        Rectangle()
            .fill(AVIATheme.aviaWhite.opacity(0.12))
            .frame(width: 1, height: 30)
    }

    private func pulseSegment(value: Int, label: String, icon: String, emphasised: Bool = false) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(emphasised ? AVIATheme.aviaWhite : AVIATheme.aviaWhite.opacity(0.55))
                Text("\(value)")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
            }
            Text(label.uppercased())
                .font(.neueCaption2Medium)
                .tracking(0.5)
                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Client Profile Banner

/// Branded cover header for a customer's CRM record. Replaces the flat initials
/// row with a branded AVIA cover, a large customer photo that staff can upload
/// or change in-place, identity details, and an active-builds summary.
struct ClientProfileBanner: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser

    @State private var avatarUrl: String
    @State private var preview: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploading: Bool = false
    @State private var uploadError: String?

    init(client: ClientUser) {
        self.client = client
        _avatarUrl = State(initialValue: client.avatarUrl ?? "")
    }

    private var clientBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.hasClient(id: client.id) }
    }

    private var displayName: String {
        let name = client.fullName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? client.email : name
    }

    var body: some View {
        BentoCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                cover
                infoArea
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhoto(newItem) }
        }
    }

    private var cover: some View {
        AVIABrandBackdrop(watermarkWidth: 150, watermarkOffset: CGSize(width: 88, height: -4))
            .frame(height: 92)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 5) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 10))
                    Text("CLIENT")
                        .font(.neueCaption2Medium)
                        .tracking(1.2)
                }
                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(AVIATheme.aviaWhite.opacity(0.12))
                .clipShape(.capsule)
                .padding(14)
            }
            .clipShape(.rect(cornerRadius: 18))
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                avatarBlock
                    .padding(.top, -38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(2)
                    Text(client.email)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if !client.phone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(client.phone)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let uploadError {
                Text(uploadError)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.destructive)
            }

            if !clientBuilds.isEmpty {
                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVE BUILDS")
                        .font(.neueCaption2Medium)
                        .tracking(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    ForEach(clientBuilds) { build in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(build.overallProgress >= 0.7 ? AVIATheme.success : build.overallProgress > 0 ? AVIATheme.warning : AVIATheme.textTertiary)
                                .frame(width: 6, height: 6)
                            Text(build.homeDesign)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                            Text("\(Int(build.overallProgress * 100))%")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avatarBlock: some View {
        avatarImage
            .frame(width: 76, height: 76)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(AVIATheme.background, lineWidth: 4)
            }
            .overlay {
                if isUploading {
                    Circle().fill(Color.black.opacity(0.4))
                    ProgressView().tint(AVIATheme.aviaWhite)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 26, height: 26)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(AVIATheme.background, lineWidth: 2)
                        }
                }
                .disabled(isUploading)
            }
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let preview {
            Image(uiImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    initialsFill
                }
            }
        } else {
            initialsFill
        }
    }

    private var initialsFill: some View {
        Text(client.initials.isEmpty ? "?" : client.initials)
            .font(.neueCorpMedium(28))
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(width: 76, height: 76)
            .background(AVIATheme.primaryGradient)
    }

    private func handlePhoto(_ item: PhotosPickerItem) async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        guard let data = await ImageUploadService.shared.loadTransferable(from: item) else {
            uploadError = "Couldn't load the selected image."
            return
        }
        if let uiImg = UIImage(data: data) {
            preview = uiImg
        }

        let fileName = "\(client.id)_\(Int(Date().timeIntervalSince1970)).jpg"
        guard let url = await ImageUploadService.shared.uploadImage(data, folder: "avatars", fileName: fileName) else {
            uploadError = "Upload failed. Please try again."
            preview = nil
            return
        }

        avatarUrl = url
        await SupabaseService.shared.updateProfileField(userId: client.id, fields: ["avatar_url": url])
        await viewModel.fetchAllUsersFromSupabase()
        photoItem = nil
    }
}

// MARK: - Client Face Pile

/// An overlapping row of customer profile photos, used wherever a record can
/// belong to multiple customers (e.g. co-buyers on a build). Keeps the customer
/// identity visible and personal rather than collapsing it to a count. Falls
/// back to initials when a photo isn't set.
struct ClientFacePile: View {
    let clients: [ClientUser]
    var size: CGFloat = 34
    var maxVisible: Int = 4
    var ringColor: Color = AVIATheme.cardBackground

    private var visible: [ClientUser] {
        Array(clients.prefix(maxVisible))
    }

    private var overflow: Int {
        max(0, clients.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(visible) { client in
                UserAvatarView(user: client, size: size)
                    .overlay { Circle().stroke(ringColor, lineWidth: 2) }
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.neueCorpMedium(max(11, size * 0.34)))
                    .foregroundStyle(AVIATheme.textSecondary)
                    .frame(width: size, height: size)
                    .background(AVIATheme.warmAccent)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(ringColor, lineWidth: 2) }
            }
        }
    }
}
