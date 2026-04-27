import Foundation

protocol VineyardRepositoryProtocol: Sendable {
    func listMyVineyards() async throws -> [BackendVineyard]
    func createVineyard(name: String, country: String?) async throws -> BackendVineyard
    func updateVineyard(_ vineyard: BackendVineyard) async throws
    func softDeleteVineyard(id: UUID) async throws
}
