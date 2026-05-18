import Foundation
import LocalAuthentication

/// Wraps LocalAuthentication for Face ID / Touch ID / device passcode auth.
///
/// Usage:
/// - After a successful email+password sign-in, ask the user if they want to
///   enable Face ID. If they accept, call `setEnabled(true)`.
/// - On app launch, if `isEnabled` is true and a Supabase session is being
///   restored, call `authenticate(reason:)` before exposing app content.
/// - On the login screen, if `isEnabled` is true and there is a stored
///   Supabase session, show a "Sign in with Face ID" button that calls
///   `authenticate(reason:)` and on success restores access without password.
@Observable
final class BiometricAuthService {
    enum BiometryKind {
        case none
        case faceID
        case touchID
        case opticID

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none: return "Biometrics"
            }
        }

        var systemImage: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.shield"
            }
        }
    }

    private let enabledKey = "avia_biometric_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Whether this device has biometrics (or passcode) configured.
    var isAvailable: Bool {
        var error: NSError?
        let ctx = LAContext()
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometryKind: BiometryKind {
        var error: NSError?
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch ctx.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Prompts the user for biometrics. Falls back to device passcode if
    /// biometrics fail (so a user with a covered face can still get in).
    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
