import Foundation
import AuthenticationServices
import Supabase

/// Handles connecting a staff member's Microsoft 365 account and sending email
/// through the `microsoft-mail` Supabase Edge Function (which sends via delegated
/// Microsoft Graph so the message goes out from the staff member's real mailbox).
@MainActor
@Observable
final class MicrosoftMailService: NSObject {
    static let shared = MicrosoftMailService()

    /// Custom URL scheme the edge function bounces back to once OAuth completes.
    /// ASWebAuthenticationSession intercepts this without needing Info.plist setup.
    private let callbackScheme = "aviahomes"

    private var authSession: ASWebAuthenticationSession?

    private var functionBaseURL: String? {
        let raw = Config.EXPO_PUBLIC_SUPABASE_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return "\(raw)/functions/v1/microsoft-mail"
    }

    private var anonKey: String {
        Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Connect

    /// Opens the Microsoft consent flow for the signed-in staff user. The edge
    /// function now requires an authenticated request and returns the consent
    /// URL (with a signed state) instead of redirecting, so we fetch it first
    /// and then hand the Microsoft URL to ASWebAuthenticationSession.
    @discardableResult
    func connect(staffId: String) async -> Bool {
        guard let base = functionBaseURL,
              let requestURL = URL(string: "\(base)?action=start") else { return false }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        await applyHeaders(&request)

        guard let startURL: URL = await {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let urlString = parsed["url"] as? String else { return nil }
                return URL(string: urlString)
            } catch {
                print("[MicrosoftMailService] start request error: \(error)")
                return nil
            }
        }() else { return false }

        return await withCheckedContinuation { continuation in
            var didResume = false
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                guard !didResume else { return }
                didResume = true
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError,
                       asError.code == .canceledLogin {
                        continuation.resume(returning: false)
                        return
                    }
                    print("[MicrosoftMailService] connect error: \(error)")
                    continuation.resume(returning: false)
                    return
                }
                let success = callbackURL?.host == "ms-connected"
                continuation.resume(returning: success)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            if !session.start() {
                if !didResume {
                    didResume = true
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Status

    func fetchStatus(staffId: String) async -> MicrosoftAccount? {
        await SupabaseService.shared.fetchMicrosoftAccount(userId: staffId)
    }

    @discardableResult
    func disconnect(staffId: String) async -> Bool {
        guard let base = functionBaseURL, let url = URL(string: "\(base)?action=disconnect") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await applyHeaders(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["uid": staffId])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[MicrosoftMailService] disconnect error: \(error)")
            return false
        }
    }

    // MARK: - Send

    struct SendResult: Sendable {
        let success: Bool
        let message: String?
        let sendId: String?
    }

    func sendEmail(
        staffId: String,
        clientId: String,
        to: String,
        subject: String,
        body: String,
        documentURL: String?,
        documentName: String?,
        documentId: String?
    ) async -> SendResult {
        guard let base = functionBaseURL, let url = URL(string: "\(base)?action=send") else {
            return SendResult(success: false, message: "Email service is not configured.", sendId: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await applyHeaders(&request)
        var payload: [String: Any] = [
            "staff_id": staffId,
            "client_id": clientId,
            "to": to,
            "subject": subject,
            "body": body,
        ]
        if let documentURL { payload["document_url"] = documentURL }
        if let documentName { payload["document_name"] = documentName }
        if let documentId { payload["document_id"] = documentId }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if status == 200 {
                return SendResult(success: true, message: nil, sendId: parsed?["id"] as? String)
            }
            let message = (parsed?["message"] as? String) ?? "Couldn't send the email."
            return SendResult(success: false, message: message, sendId: nil)
        } catch {
            print("[MicrosoftMailService] send error: \(error)")
            return SendResult(success: false, message: "Network error sending the email.", sendId: nil)
        }
    }

    /// Authenticates requests with the signed-in user's JWT — the edge function
    /// rejects anon-key calls now that it verifies the caller's identity & role.
    private func applyHeaders(_ request: inout URLRequest) async {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        if let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else if !anonKey.isEmpty {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
    }
}

extension MicrosoftMailService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
                ?? scenes.first as? UIWindowScene
            return windowScene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
