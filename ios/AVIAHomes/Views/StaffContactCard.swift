import SwiftUI

struct StaffContactCard: View {
    let staffUser: ClientUser

    var body: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                avatarView
                VStack(alignment: .leading, spacing: 4) {
                    Text(staffUser.fullName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let title = staffUser.displayTitle, !title.isEmpty {
                        Text(title)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    HStack(spacing: 8) {
                        if !staffUser.phone.isEmpty, let phoneURL = URL(string: "tel:\(staffUser.phone)") {
                            Link(destination: phoneURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "phone.fill")
                                        .font(.neueCorp(10))
                                    Text("Call")
                                        .font(.neueCaption2Medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AVIATheme.tealGradient)
                                .clipShape(Capsule())
                            }
                        }
                        if !staffUser.email.isEmpty, let mailURL = URL(string: "mailto:\(staffUser.email)") {
                            Link(destination: mailURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "envelope.fill")
                                        .font(.neueCorp(10))
                                    Text("Email")
                                        .font(.neueCaption2Medium)
                                }
                                .foregroundStyle(AVIATheme.teal)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AVIATheme.teal.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = staffUser.avatarUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsCircle
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        Text(staffUser.initials)
            .font(.neueCorpMedium(18))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(AVIATheme.tealGradient)
            .clipShape(Circle())
    }
}
