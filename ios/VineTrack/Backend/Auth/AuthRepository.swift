import Foundation

protocol AuthRepository: Sendable {
    func restoreSession() async throws -> AppUser?
    func signInWithEmail(email: String, password: String) async throws -> AppUser
    func signUpWithEmail(name: String, email: String, password: String) async throws -> AppUser?
    func signOut() async throws
    func sendPasswordReset(email: String) async throws
    func updatePassword(_ newPassword: String) async throws
    var currentUserId: UUID? { get }
}
