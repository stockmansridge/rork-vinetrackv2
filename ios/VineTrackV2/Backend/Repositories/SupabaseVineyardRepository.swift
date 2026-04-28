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
        guard provider.client.auth.currentUser != nil else { throw BackendRepositoryError.missingAuthenticatedUser }
        let vineyards: [BackendVineyard] = try await provider.client
            .rpc("create_vineyard_with_owner", params: CreateVineyardRequest(name: name, country: country))
            .execute()
            .value
        guard let vineyard = vineyards.first else { throw BackendRepositoryError.emptyResponse }
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

nonisolated private struct CreateVineyardRequest: Encodable, Sendable {
    let name: String
    let country: String?

    enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case country = "p_country"
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

