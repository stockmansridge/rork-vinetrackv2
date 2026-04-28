import Foundation
import Observation

@Observable
@MainActor
final class NewBackendAuthService {
    var isLoading: Bool = false
    var isSignedIn: Bool = false
    var userId: UUID?
    var userEmail: String?
    var userName: String?
    var errorMessage: String?
    var pendingInvitations: [BackendInvitation] = []

    private let authRepository: any AuthRepository
    private let profileRepository: any ProfileRepositoryProtocol
    private let teamRepository: any TeamRepositoryProtocol

    init(
        authRepository: any AuthRepository = SupabaseAuthRepository(),
        profileRepository: any ProfileRepositoryProtocol = SupabaseProfileRepository(),
        teamRepository: any TeamRepositoryProtocol = SupabaseTeamRepository()
    ) {
        self.authRepository = authRepository
        self.profileRepository = profileRepository
        self.teamRepository = teamRepository
    }

    func restoreSession() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await authRepository.restoreSession()
            applyUser(user)
            if isSignedIn {
                await refreshProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
            applyUser(nil)
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let user = try await authRepository.signInWithEmail(email: trimmedEmail, password: password)
            applyUser(user)
            await refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let user = try await authRepository.signUpWithEmail(name: trimmedName, email: trimmedEmail, password: password)
            applyUser(user)
            if isSignedIn {
                try? await profileRepository.upsertMyProfile(
                    fullName: trimmedName.isEmpty ? nil : trimmedName,
                    email: trimmedEmail.isEmpty ? nil : trimmedEmail
                )
                if !trimmedName.isEmpty {
                    userName = trimmedName
                }
            } else {
                errorMessage = "Check your email to confirm your account, then sign in."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authRepository.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        applyUser(nil)
        pendingInvitations = []
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await authRepository.sendPasswordReset(email: trimmedEmail)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPendingInvitations() async {
        guard isSignedIn else { return }
        do {
            pendingInvitations = try await teamRepository.listPendingInvitations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptInvitation(_ invitation: BackendInvitation) async {
        do {
            try await teamRepository.acceptInvitation(invitationId: invitation.id)
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineInvitation(_ invitation: BackendInvitation) async {
        do {
            try await teamRepository.declineInvitation(invitationId: invitation.id)
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyUser(_ user: AppUser?) {
        if let user {
            isSignedIn = true
            userId = user.id
            userEmail = user.email
            userName = user.displayName.isEmpty ? user.email : user.displayName
        } else {
            isSignedIn = false
            userId = nil
            userEmail = nil
            userName = nil
        }
    }

    private func refreshProfile() async {
        do {
            if let profile = try await profileRepository.getMyProfile() {
                userEmail = profile.email
                if let fullName = profile.fullName, !fullName.isEmpty {
                    userName = fullName
                }
            }
        } catch {
            // Silent — profile fetch failure should not block sign-in flow.
        }
    }
}
