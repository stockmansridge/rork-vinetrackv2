import Foundation

nonisolated struct BackendVineyard: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let ownerId: UUID?
    let country: String?
    let logoPath: String?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case country
        case logoPath = "logo_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
