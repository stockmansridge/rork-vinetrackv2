import Foundation
import Supabase

final class SupabaseVineyardRepository: VineyardRepositoryProtocol {
    private let provider: SupabaseClientProvider

    init(provider: SupabaseClientProvider = .shared) {
        self.provider = provider
    }

    func listMyVineyards() async throws -> [BackendVineyard] {
        guard provider.isConfigured else { throw BackendRepositoryError.missingSupabaseConfiguration }
        return try await provider.client
            .from("vineyards")
            .select()
            .is("deleted_at", value: nil)
            .order("name", ascending: true)
            .execute()
            .value
    }

    func createVineyard(name: String, country: String?) async throws -> BackendVineyard {
        guard provider.isConfigured else { throw BackendRepositoryError.missingSupabaseConfiguration }
        guard let userId = provider.client.auth.currentUser?.id else { throw BackendRepositoryError.missingAuthenticatedUser }
        let vineyard: BackendVineyard = try await provider.client
            .from("vineyards")
            .insert(VineyardInsert(name: name, ownerId: userId, country: country))
            .select()
            .single()
            .execute()
            .value
        try await provider.client
            .from("vineyard_members")
            .insert(VineyardMemberInsert(vineyardId: vineyard.id, userId: userId, role: .owner, displayName: nil))
            .execute()
        return vineyard
    }

    func updateVineyard(_ vineyard: BackendVineyard) async throws {
        guard provider.isConfigured else { throw BackendRepositoryError.missingSupabaseConfiguration }
        try await provider.client
            .from("vineyards")
            .update(VineyardUpdate(name: vineyard.name, country: vineyard.country, logoPath: vineyard.logoPath))
            .eq("id", value: vineyard.id.uuidString)
            .execute()
    }

    func softDeleteVineyard(id: UUID) async throws {
        guard provider.isConfigured else { throw BackendRepositoryError.missingSupabaseConfiguration }
        try await provider.client
            .from("vineyards")
            .update(VineyardSoftDelete(deletedAt: Date()))
            .eq("id", value: id.uuidString)
            .execute()
    }
}

nonisolated private struct VineyardInsert: Encodable, Sendable {
    let name: String
    let ownerId: UUID
    let country: String?

    enum CodingKeys: String, CodingKey {
        case name
        case ownerId = "owner_id"
        case country
    }
}

nonisolated private struct VineyardUpdate: Encodable, Sendable {
    let name: String
    let country: String?
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case name
        case country
        case logoPath = "logo_path"
    }
}

nonisolated private struct VineyardSoftDelete: Encodable, Sendable {
    let deletedAt: Date

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

nonisolated private struct VineyardMemberInsert: Encodable, Sendable {
    let vineyardId: UUID
    let userId: UUID
    let role: BackendRole
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case vineyardId = "vineyard_id"
        case userId = "user_id"
        case role
        case displayName = "display_name"
    }
}
