import SwiftUI

/// Full-screen lock shown after a restored Supabase session when the user has
/// turned on biometric protection. Prompts Face ID / Touch ID automatically;
/// the user can retry, fall back to passcode, or sign out entirely.
struct BiometricLockView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isPrompting = false
    @State private var failedOnce = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("AVIALogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140)
                .foregroundStyle(AVIATheme.timelessBrown)

            VStack(spacing: 10) {
                Image(systemName: appViewModel.biometricAuth.biometryKind.systemImage)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.top, 4)

                Text("AVIA Homes is locked")
                    .font(.neueCorpMedium(22))
                    .foregroundStyle(AVIATheme.textPrimary)

                Text(failedOnce
                     ? "Tap below to try \(appViewModel.biometricAuth.biometryKind.displayName) again."
                     : "Unlock with \(appViewModel.biometricAuth.biometryKind.displayName) to continue.")
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: appViewModel.biometricAuth.biometryKind.systemImage)
                        Text("Unlock with \(appViewModel.biometricAuth.biometryKind.displayName)")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(isPrompting)

                Button("Sign Out") {
                    appViewModel.signOut()
                }
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AVIATheme.background)
        .task { await unlock() }
    }

    private func unlock() async {
        guard !isPrompting else { return }
        isPrompting = true
        let ok = await appViewModel.unlockWithBiometrics()
        isPrompting = false
        if !ok { failedOnce = true }
    }
}
