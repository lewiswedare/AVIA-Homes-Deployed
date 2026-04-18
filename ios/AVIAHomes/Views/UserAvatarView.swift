import SwiftUI

struct UserAvatarView: View {
    let avatarUrl: String?
    let initials: String
    var size: CGFloat = 48
    var fontSize: CGFloat? = nil

    private var resolvedFontSize: CGFloat {
        fontSize ?? max(12, size * 0.36)
    }

    var body: some View {
        Group {
            if let urlString = avatarUrl,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsCircle: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.neueCorpMedium(resolvedFontSize))
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(width: size, height: size)
            .background(AVIATheme.primaryGradient)
    }
}

extension UserAvatarView {
    init(user: ClientUser, size: CGFloat = 48, fontSize: CGFloat? = nil) {
        self.init(avatarUrl: user.avatarUrl, initials: user.initials, size: size, fontSize: fontSize)
    }
}
