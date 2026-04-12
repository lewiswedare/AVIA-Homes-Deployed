import Foundation
import Supabase

@Observable
class AuthService {
    var isAuthenticated: Bool = false
    var hasCompletedProfile: Bool = false
    var isLoading: Bool = false
    var isRestoringSession: Bool = true
    var errorMessage: String?
    var currentRole: UserRole = .client
    var supabaseUserId: String?

    private let supabase = SupabaseService.shared
    private let authKey = "avia_auth_state"
    private let profileKey = "avia_profile_completed"
    private let userKey = "avia_user_data"
    private let roleKey = "avia_user_role"
    private let userIdKey = "avia_user_id"

    static let demoAccounts: [(email: String, password: String, role: UserRole, firstName: String, lastName: String)] = []

    private let demoIds: [String: String] = [:]

    init() {
        if let roleString = UserDefaults.standard.string(forKey: roleKey),
           let role = UserRole(rawValue: roleString) {
            currentRole = role
        }
        supabaseUserId = UserDefaults.standard.string(forKey: userIdKey)
    }

    var isDemoMode: Bool {
        !supabase.isConfigured
    }

    func demoAccount(for email: String, password: String) -> (email: String, password: String, role: UserRole, firstName: String, lastName: String)? {
        Self.demoAccounts.first { $0.email.lowercased() == email.lowercased() && $0.password == password }
    }

    func demoId(for email: String) -> String {
        demoIds[email.lowercased()] ?? UUID().uuidString
    }

    func restoreSession() async -> String? {
        let hadPreviousSession = UserDefaults.standard.bool(forKey: authKey)
        guard hadPreviousSession else {
            isRestoringSession = false
            return nil
        }

        guard supabase.isConfigured else {
            if let savedRole = UserDefaults.standard.string(forKey: roleKey),
               let role = UserRole(rawValue: savedRole) {
                currentRole = role
            }
            hasCompletedProfile = UserDefaults.standard.bool(forKey: profileKey)
            isAuthenticated = true
            isRestoringSession = false
            return supabaseUserId
        }

        do {
            let session = try await supabase.client.auth.session
            let userId = session.user.id.uuidString.lowercased()
            supabaseUserId = userId
            isAuthenticated = true
            return userId
        } catch {
            UserDefaults.standard.set(false, forKey: authKey)
            UserDefaults.standard.set(false, forKey: profileKey)
            isAuthenticated = false
            hasCompletedProfile = false
            isRestoringSession = false
            return nil
        }
    }

    func finishRestoring() {
        isRestoringSession = false
    }

    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        isRestoringSession = false
        errorMessage = nil

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            isLoading = false
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            isLoading = false
            return false
        }

        if supabase.isConfigured {
            do {
                let session = try await supabase.client.auth.signIn(email: email, password: password)
                supabaseUserId = session.user.id.uuidString.lowercased()
                UserDefaults.standard.set(supabaseUserId, forKey: userIdKey)
                if let profile = await supabase.fetchProfile(userId: session.user.id.uuidString.lowercased()) {
                    currentRole = profile.role
                    hasCompletedProfile = profile.profileCompleted
                } else {
                    currentRole = .client
                    hasCompletedProfile = false
                }
                isAuthenticated = true
                persistLocalState()
                isLoading = false
                return true
            } catch {
                if demoAccount(for: email, password: password) == nil {
                    errorMessage = parseAuthError(error)
                    isLoading = false
                    return false
                }
            }
        }

        guard let demo = demoAccount(for: email, password: password) else {
            if !supabase.isConfigured {
                errorMessage = "Please check your email and password."
            } else {
                errorMessage = "Invalid email or password."
            }
            isLoading = false
            return false
        }

        currentRole = demo.role
        supabaseUserId = nil
        hasCompletedProfile = true
        isAuthenticated = true
        persistLocalState()
        isLoading = false
        return true
    }

    func signUp(email: String, password: String, confirmPassword: String, firstName: String = "", lastName: String = "", phone: String = "") async -> Bool {
        isLoading = true
        isRestoringSession = false
        errorMessage = nil

        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            isLoading = false
            return false
        }

        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address."
            isLoading = false
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            isLoading = false
            return false
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            isLoading = false
            return false
        }

        if supabase.isConfigured {
            do {
                var metadata: [String: AnyJSON] = [:]
                if !firstName.isEmpty { metadata["first_name"] = .string(firstName) }
                if !lastName.isEmpty { metadata["last_name"] = .string(lastName) }
                if !phone.isEmpty { metadata["phone"] = .string(phone) }

                let authResponse: AuthResponse
                if metadata.isEmpty {
                    authResponse = try await supabase.client.auth.signUp(email: email, password: password)
                } else {
                    authResponse = try await supabase.client.auth.signUp(email: email, password: password, data: metadata)
                }
                let userId = authResponse.user.id.uuidString.lowercased()
                supabaseUserId = userId
                UserDefaults.standard.set(userId, forKey: userIdKey)
                print("[AuthService] signUp success: userId=\(userId), email=\(email), metadata=\(metadata)")
                if authResponse.session != nil {
                    isAuthenticated = true
                } else {
                    if let session = try? await supabase.client.auth.session {
                        supabaseUserId = session.user.id.uuidString.lowercased()
                        UserDefaults.standard.set(supabaseUserId, forKey: userIdKey)
                        isAuthenticated = true
                    } else {
                        isAuthenticated = true
                    }
                }
                currentRole = .client
                hasCompletedProfile = false
                persistLocalState()
                isLoading = false
                return true
            } catch {
                errorMessage = parseAuthError(error)
                isLoading = false
                return false
            }
        }

        currentRole = .client
        isAuthenticated = true
        hasCompletedProfile = false
        persistLocalState()
        isLoading = false
        return true
    }

    func updateUserMetadata(firstName: String, lastName: String, phone: String) async {
        guard supabase.isConfigured else { return }
        do {
            let metadata: [String: AnyJSON] = [
                "first_name": .string(firstName),
                "last_name": .string(lastName),
                "phone": .string(phone)
            ]
            try await supabase.client.auth.update(user: UserAttributes(data: metadata))
            print("[AuthService] updateUserMetadata SUCCESS: \(firstName) \(lastName)")
        } catch {
            print("[AuthService] updateUserMetadata FAILED: \(error)")
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        guard !email.isEmpty, email.contains("@") else {
            errorMessage = "Please enter a valid email address."
            isLoading = false
            return false
        }

        if supabase.isConfigured {
            do {
                try await supabase.client.auth.resetPasswordForEmail(email)
                isLoading = false
                return true
            } catch {
                errorMessage = parseAuthError(error)
                isLoading = false
                return false
            }
        }

        try? await Task.sleep(for: .seconds(1))
        isLoading = false
        return true
    }

    func completeProfile() {
        hasCompletedProfile = true
        UserDefaults.standard.set(true, forKey: profileKey)
    }

    func updateRole(_ role: UserRole) {
        currentRole = role
        UserDefaults.standard.set(role.rawValue, forKey: roleKey)
    }

    func signOut() {
        isAuthenticated = false
        hasCompletedProfile = false
        currentRole = .client
        supabaseUserId = nil
        UserDefaults.standard.set(false, forKey: authKey)
        UserDefaults.standard.set(false, forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: roleKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)

        if supabase.isConfigured {
            Task {
                try? await supabase.client.auth.signOut()
            }
        }
    }

    func saveUserProfile(_ user: ClientUser) {
        if let data = try? JSONEncoder().encode(UserData(from: user)) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func loadUserProfile() -> ClientUser? {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return nil
        }
        return userData.toClientUser()
    }

    private func persistLocalState() {
        UserDefaults.standard.set(isAuthenticated, forKey: authKey)
        UserDefaults.standard.set(hasCompletedProfile, forKey: profileKey)
        UserDefaults.standard.set(currentRole.rawValue, forKey: roleKey)
    }

    private func parseAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid") || message.contains("credentials") {
            return "Invalid email or password."
        } else if message.contains("already registered") || message.contains("already been registered") {
            return "An account with this email already exists."
        } else if message.contains("email") && message.contains("confirm") {
            return "Please check your email to confirm your account."
        } else if message.contains("network") || message.contains("connection") {
            return "Network error. Please check your connection."
        }
        return "Something went wrong. Please try again."
    }
}

nonisolated struct UserData: Codable, Sendable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let address: String
    let homeDesign: String
    let lotNumber: String
    let contractDateInterval: TimeInterval
    let profileCompleted: Bool
    let role: String
    let assignedClientIds: [String]
    let assignedStaffId: String?
    let salesPartnerId: String?

    init(from user: ClientUser) {
        self.id = user.id
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.email = user.email
        self.phone = user.phone
        self.address = user.address
        self.homeDesign = user.homeDesign
        self.lotNumber = user.lotNumber
        self.contractDateInterval = user.contractDate.timeIntervalSince1970
        self.profileCompleted = user.profileCompleted
        self.role = user.role.rawValue
        self.assignedClientIds = user.assignedClientIds
        self.assignedStaffId = user.assignedStaffId
        self.salesPartnerId = user.salesPartnerId
    }

    func toClientUser() -> ClientUser {
        ClientUser(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address: address,
            homeDesign: homeDesign,
            lotNumber: lotNumber,
            contractDate: Date(timeIntervalSince1970: contractDateInterval),
            profileCompleted: profileCompleted,
            role: UserRole(rawValue: role) ?? .client,
            assignedClientIds: assignedClientIds,
            assignedStaffId: assignedStaffId,
            salesPartnerId: salesPartnerId
        )
    }
}
