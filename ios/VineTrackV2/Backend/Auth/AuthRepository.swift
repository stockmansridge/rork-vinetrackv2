import Foundation

protocol AuthRepository: Sendable {
    func restoreSession() async throws -> AppUser?
    func signInWithEmail(email: String, password: String) async throws -> AppUser
    func signUpWithEmail(name: String, email: String, password: String) async throws -> AppUser?
    func signOut() async throws
    func sendPasswordReset(email: String) async throws
    func verifyPasswordResetPin(email: String, pin: String) async throws -> AppUser
    func updatePassword(_ newPassword: String) async throws
    func resetPasswordWithPin(email: String, pin: String, newPassword: String) async throws -> AppUser
    var currentUserId: UUID? { get }
}
