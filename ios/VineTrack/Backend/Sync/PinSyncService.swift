import Foundation
import Observation

/// Local-first sync service for VinePin records.
/// Tracks dirty/deleted pins locally and pushes/pulls them against Supabase
/// using `SupabasePinSyncRepository`. Conflict resolution is last-write-wins
/// based on `client_updated_at`/`updated_at`.
@Observable
@MainActor
final class PinSyncService {

    enum Status: Equatable, Sendable {
        case idle
        case syncing
        case success
        case failure(String)
    }

    var syncStatus: Status = .idle
    var lastSyncDate: Date?
    var errorMessage: String?

    private weak var store: MigratedDataStore?
    private weak var auth: NewBackendAuthService?
    private let repository: any PinSyncRepositoryProtocol
    private let metadata: PinSyncMetadata
    private var isConfigured: Bool = false

    init(
        repository: (any PinSyncRepositoryProtocol)? = nil,
        metadata: PinSyncMetadata? = nil
    ) {
        self.repository = repository ?? SupabasePinSyncRepository()
        self.metadata = metadata ?? PinSyncMetadata()
    }

    // MARK: - Configuration

    func configure(store: MigratedDataStore, auth: NewBackendAuthService) {
        self.store = store
        self.auth = auth
        guard !isConfigured else { return }
        isConfigured = true
        store.onPinChanged = { [weak self] id in
            self?.markPinDirty(id)
        }
        store.onPinDeleted = { [weak self] id in
            self?.markPinDeleted(id)
        }
    }

    // MARK: - Dirty tracking

    func markPinDirty(_ id: UUID) {
        metadata.markDirty(id, at: Date())
    }

    func markPinDeleted(_ id: UUID) {
        metadata.markDeleted(id, at: Date())
    }

    // MARK: - Public sync entry points

    func syncPinsForSelectedVineyard() async {
        guard let store, let auth, auth.isSignedIn,
              let vineyardId = store.selectedVineyardId else { return }
        await sync(vineyardId: vineyardId)
    }

    func sync(vineyardId: UUID) async {
        guard SupabaseClientProvider.shared.isConfigured else {
            errorMessage = "Supabase not configured"
            syncStatus = .failure("Supabase not configured")
            return
        }
        syncStatus = .syncing
        errorMessage = nil
        do {
            try await pushLocalPins(vineyardId: vineyardId)
            try await pullRemotePins(vineyardId: vineyardId)
            metadata.setLastSync(Date(), for: vineyardId)
            lastSyncDate = Date()
            syncStatus = .success
        } catch {
            errorMessage = error.localizedDescription
            syncStatus = .failure(error.localizedDescription)
        }
    }

    // MARK: - Push

    func pushLocalPins(vineyardId: UUID) async throws {
        guard let store else { return }
        let dirty = metadata.pendingUpserts
        if !dirty.isEmpty {
            let pinsById = Dictionary(uniqueKeysWithValues: store.pins.map { ($0.id, $0) })
            var payloads: [BackendPinUpsert] = []
            var pushedIds: [UUID] = []
            for (pinId, ts) in dirty {
                guard let pin = pinsById[pinId], pin.vineyardId == vineyardId else { continue }
                payloads.append(BackendPin.upsert(from: pin, clientUpdatedAt: ts))
                pushedIds.append(pinId)
            }
            if !payloads.isEmpty {
                try await repository.upsertPins(payloads)
                metadata.clearDirty(pushedIds)
            }
        }

        let deletes = metadata.pendingDeletes
        for (pinId, _) in deletes {
            do {
                try await repository.softDeletePin(id: pinId)
                metadata.clearDeleted([pinId])
            } catch {
                // Keep the deletion pending so it retries next sync.
                throw error
            }
        }
    }

    // MARK: - Pull

    func pullRemotePins(vineyardId: UUID) async throws {
        guard let store else { return }
        let lastSync = metadata.lastSync(for: vineyardId)
        let remote = try await repository.fetchPins(vineyardId: vineyardId, since: lastSync)

        // Initial sync: if both local and remote slices are empty, nothing to do.
        // If remote is empty AND we have local pins AND we have never synced before,
        // push them all up so the cloud picks them up.
        if remote.isEmpty, lastSync == nil {
            let localForVineyard = store.pins.filter { $0.vineyardId == vineyardId }
            if !localForVineyard.isEmpty {
                let now = Date()
                let payloads = localForVineyard.map {
                    BackendPin.upsert(from: $0, clientUpdatedAt: now)
                }
                try await repository.upsertPins(payloads)
            }
            return
        }

        for backendPin in remote {
            applyRemote(backendPin, vineyardId: vineyardId, store: store)
        }
    }

    private func applyRemote(_ backendPin: BackendPin, vineyardId: UUID, store: MigratedDataStore) {
        let existingIndex = store.pins.firstIndex { $0.id == backendPin.id }

        // Soft-deleted remotely.
        if backendPin.deletedAt != nil {
            if existingIndex != nil {
                store.applyRemotePinDelete(backendPin.id)
            }
            metadata.clearDirty([backendPin.id])
            metadata.clearDeleted([backendPin.id])
            return
        }

        // Last-write-wins: only apply remote if it's newer than the local pending change.
        if let pendingDirtyAt = metadata.pendingUpserts[backendPin.id] {
            let remoteAt = backendPin.clientUpdatedAt ?? backendPin.updatedAt ?? .distantPast
            if pendingDirtyAt > remoteAt {
                return
            }
        }

        let existingPhoto: Data? = existingIndex.flatMap { store.pins[$0].photoData }
        guard let mapped = backendPin.toVinePin(preservingPhoto: existingPhoto) else { return }
        store.applyRemotePinUpsert(mapped)
        metadata.clearDirty([backendPin.id])
    }
}

// MARK: - Metadata

@MainActor
final class PinSyncMetadata {
    private let persistence: PersistenceStore
    private let key: String = "vinetrack_pin_sync_metadata"
    private var state: State

    nonisolated struct State: Codable, Sendable {
        var lastSyncByVineyard: [UUID: Date] = [:]
        var pendingUpserts: [UUID: Date] = [:]
        var pendingDeletes: [UUID: Date] = [:]
    }

    init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        self.state = persistence.load(key: key) ?? State()
    }

    var pendingUpserts: [UUID: Date] { state.pendingUpserts }
    var pendingDeletes: [UUID: Date] { state.pendingDeletes }

    func lastSync(for vineyardId: UUID) -> Date? {
        state.lastSyncByVineyard[vineyardId]
    }

    func setLastSync(_ date: Date, for vineyardId: UUID) {
        state.lastSyncByVineyard[vineyardId] = date
        save()
    }

    func markDirty(_ id: UUID, at date: Date) {
        state.pendingUpserts[id] = date
        save()
    }

    func markDeleted(_ id: UUID, at date: Date) {
        state.pendingUpserts.removeValue(forKey: id)
        state.pendingDeletes[id] = date
        save()
    }

    func clearDirty(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        for id in ids { state.pendingUpserts.removeValue(forKey: id) }
        save()
    }

    func clearDeleted(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        for id in ids { state.pendingDeletes.removeValue(forKey: id) }
        save()
    }

    private func save() {
        persistence.save(state, key: key)
    }
}
