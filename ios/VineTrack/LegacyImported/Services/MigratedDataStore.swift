import Foundation
import Observation

/// Backend-neutral local data store. Uses the imported legacy repositories and
/// PersistenceStore for storage. Has no knowledge of AuthService, CloudSyncService,
/// SupabaseManager, AnalyticsService, AuditService, or AccessControl.
///
/// This is the Phase 4 replacement for the old DataStore — it loads/saves local
/// state and exposes simple CRUD methods. Backend wiring will be added in later phases.
@Observable
@MainActor
final class MigratedDataStore {

    // MARK: - State

    var vineyards: [Vineyard] = []
    var selectedVineyardId: UUID?

    var pins: [VinePin] = []
    var paddocks: [Paddock] = []
    var trips: [Trip] = []

    var repairButtons: [ButtonConfig] = []
    var growthButtons: [ButtonConfig] = []
    var settings: AppSettings = AppSettings()
    var savedCustomPatterns: [SavedCustomPattern] = []

    var sprayRecords: [SprayRecord] = []
    var savedChemicals: [SavedChemical] = []
    var savedSprayPresets: [SavedSprayPreset] = []
    var savedEquipmentOptions: [SavedEquipmentOption] = []
    var sprayEquipment: [SprayEquipmentItem] = []

    var tractors: [Tractor] = []
    var fuelPurchases: [FuelPurchase] = []
    var operatorCategories: [OperatorCategory] = []
    var buttonTemplates: [ButtonTemplate] = []

    var yieldSessions: [YieldEstimationSession] = []
    var damageRecords: [DamageRecord] = []
    var historicalYieldRecords: [HistoricalYieldRecord] = []

    var maintenanceLogs: [MaintenanceLog] = []
    var workTasks: [WorkTask] = []

    var grapeVarieties: [GrapeVariety] = []

    var selectedTab: Int = 0

    // MARK: - Sync hooks (Phase 10B)

    /// Called when a pin is added/updated locally. Sync services observe this
    /// to mark the pin as dirty for upload.
    var onPinChanged: ((UUID) -> Void)?
    /// Called when a pin is deleted locally.
    var onPinDeleted: ((UUID) -> Void)?

    /// Called when a paddock is added/updated locally. Sync services observe
    /// this to mark the paddock as dirty for upload.
    var onPaddockChanged: ((UUID) -> Void)?
    /// Called when a paddock is deleted locally.
    var onPaddockDeleted: ((UUID) -> Void)?

    /// Called when a trip is started/updated/ended locally. Sync services observe
    /// this to mark the trip as dirty for upload.
    var onTripChanged: ((UUID) -> Void)?
    /// Called when a trip is deleted locally.
    var onTripDeleted: ((UUID) -> Void)?

    // MARK: - Repositories

    let vineyardRepo: VineyardRepository
    let pinRepo: PinRepository
    let tripRepo: TripRepository
    let workTaskRepo: WorkTaskRepository
    let maintenanceLogRepo: MaintenanceLogRepository
    let sprayRepo: SprayRepository
    let settingsRepo: SettingsRepository
    let yieldRepo: YieldRepository

    private let persistence: PersistenceStore

    // MARK: - Storage keys for collections without a dedicated repository

    private enum Keys {
        static let paddocks = "vinetrack_paddocks"
        static let repairButtons = "vinetrack_repair_buttons"
        static let growthButtons = "vinetrack_growth_buttons"
        static let savedCustomPatterns = "vinetrack_saved_custom_patterns"
        static let tractors = "vinetrack_tractors"
        static let fuelPurchases = "vinetrack_fuel_purchases"
        static let operatorCategories = "vinetrack_operator_categories"
        static let buttonTemplates = "vinetrack_button_templates"
        static let grapeVarieties = "vinetrack_grape_varieties"
        static let selectedVineyardId = "vinetrack_selected_vineyard_id"
    }

    // MARK: - Init

    init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        self.vineyardRepo = VineyardRepository(persistence: persistence)
        self.pinRepo = PinRepository(persistence: persistence)
        self.tripRepo = TripRepository(persistence: persistence)
        self.workTaskRepo = WorkTaskRepository(persistence: persistence)
        self.maintenanceLogRepo = MaintenanceLogRepository(persistence: persistence)
        self.sprayRepo = SprayRepository(persistence: persistence)
        self.settingsRepo = SettingsRepository(persistence: persistence)
        self.yieldRepo = YieldRepository(persistence: persistence)
        load()
    }

    // MARK: - Lifecycle

    func load() {
        vineyards = vineyardRepo.loadAll()

        if let stored: SelectedVineyardWrapper = persistence.load(key: Keys.selectedVineyardId) {
            selectedVineyardId = stored.id
        }
        if selectedVineyardId == nil, let first = vineyards.first {
            selectedVineyardId = first.id
        }

        repairButtons = persistence.load(key: Keys.repairButtons) ?? []
        growthButtons = persistence.load(key: Keys.growthButtons) ?? []
        savedCustomPatterns = persistence.load(key: Keys.savedCustomPatterns) ?? []
        tractors = persistence.load(key: Keys.tractors) ?? []
        fuelPurchases = persistence.load(key: Keys.fuelPurchases) ?? []
        operatorCategories = persistence.load(key: Keys.operatorCategories) ?? []
        buttonTemplates = persistence.load(key: Keys.buttonTemplates) ?? []
        grapeVarieties = persistence.load(key: Keys.grapeVarieties) ?? []

        reloadCurrentVineyardData()
    }

    /// Reload all per-vineyard scoped collections from disk for the currently selected vineyard.
    func reloadCurrentVineyardData() {
        guard let vineyardId = selectedVineyardId else {
            pins = []
            paddocks = []
            trips = []
            sprayRecords = []
            savedChemicals = []
            savedSprayPresets = []
            savedEquipmentOptions = []
            sprayEquipment = []
            yieldSessions = []
            damageRecords = []
            historicalYieldRecords = []
            maintenanceLogs = []
            workTasks = []
            settings = AppSettings()
            return
        }

        pins = pinRepo.load(for: vineyardId)
        trips = tripRepo.load(for: vineyardId)
        workTasks = workTaskRepo.load(for: vineyardId)
        maintenanceLogs = maintenanceLogRepo.load(for: vineyardId)

        sprayRecords = sprayRepo.loadRecords(for: vineyardId)
        savedChemicals = sprayRepo.loadChemicals(for: vineyardId)
        savedSprayPresets = sprayRepo.loadPresets(for: vineyardId)
        savedEquipmentOptions = sprayRepo.loadEquipmentOptions(for: vineyardId)
        sprayEquipment = sprayRepo.loadEquipment(for: vineyardId)

        yieldSessions = yieldRepo.loadSessions(for: vineyardId)
        damageRecords = yieldRepo.loadDamage(for: vineyardId)
        historicalYieldRecords = yieldRepo.loadHistorical(for: vineyardId)

        settings = settingsRepo.load(for: vineyardId)

        let allPaddocks: [Paddock] = persistence.load(key: Keys.paddocks) ?? []
        paddocks = allPaddocks.filter { $0.vineyardId == vineyardId }
    }

    /// Clear in-memory state without touching disk.
    func clearInMemoryState() {
        vineyards = []
        selectedVineyardId = nil
        pins = []
        paddocks = []
        trips = []
        repairButtons = []
        growthButtons = []
        settings = AppSettings()
        savedCustomPatterns = []
        sprayRecords = []
        savedChemicals = []
        savedSprayPresets = []
        savedEquipmentOptions = []
        sprayEquipment = []
        tractors = []
        fuelPurchases = []
        operatorCategories = []
        buttonTemplates = []
        yieldSessions = []
        damageRecords = []
        historicalYieldRecords = []
        maintenanceLogs = []
        workTasks = []
        grapeVarieties = []
        selectedTab = 0
    }

    /// Wipe all locally persisted data and reset in-memory state.
    func deleteAllLocalData() {
        let keys: [String] = [
            VineyardRepository.storageKey,
            PinRepository.storageKey,
            TripRepository.storageKey,
            WorkTaskRepository.storageKey,
            MaintenanceLogRepository.storageKey,
            SprayRepository.recordsKey,
            SprayRepository.savedChemicalsKey,
            SprayRepository.savedPresetsKey,
            SprayRepository.savedEquipmentOptionsKey,
            SprayRepository.equipmentKey,
            SettingsRepository.storageKey,
            YieldRepository.sessionsKey,
            YieldRepository.damageKey,
            YieldRepository.historicalKey,
            Keys.paddocks,
            Keys.repairButtons,
            Keys.growthButtons,
            Keys.savedCustomPatterns,
            Keys.tractors,
            Keys.fuelPurchases,
            Keys.operatorCategories,
            Keys.buttonTemplates,
            Keys.grapeVarieties,
            Keys.selectedVineyardId,
        ]
        for key in keys {
            persistence.remove(key: key)
        }
        clearInMemoryState()
    }

    // MARK: - Vineyard selection

    var selectedVineyard: Vineyard? {
        guard let id = selectedVineyardId else { return nil }
        return vineyards.first { $0.id == id }
    }

    func selectVineyard(_ vineyard: Vineyard) {
        selectedVineyardId = vineyard.id
        persistence.save(SelectedVineyardWrapper(id: vineyard.id), key: Keys.selectedVineyardId)
        reloadCurrentVineyardData()
    }

    // MARK: - Vineyard upsert

    func upsertLocalVineyard(_ vineyard: Vineyard) {
        vineyards = vineyardRepo.upsert(vineyard)
        if selectedVineyardId == nil {
            selectVineyard(vineyard)
        }
    }

    func upsertLocalVineyards(_ items: [Vineyard]) {
        for item in items {
            vineyards = vineyardRepo.upsert(item)
        }
        if selectedVineyardId == nil, let first = vineyards.first {
            selectVineyard(first)
        }
    }

    /// Map BackendVineyard records into the local `Vineyard` model, preserving local
    /// fields like `users` where possible.
    func mapBackendVineyardsIntoLocal(_ backendVineyards: [BackendVineyard]) {
        let existing = vineyardRepo.loadAll()
        var merged: [Vineyard] = []
        for backend in backendVineyards {
            if let local = existing.first(where: { $0.id == backend.id }) {
                var updated = local
                updated.name = backend.name
                updated.country = backend.country ?? local.country
                merged.append(updated)
            } else {
                let mapped = Vineyard(
                    id: backend.id,
                    name: backend.name,
                    users: [],
                    createdAt: backend.createdAt ?? Date(),
                    logoData: nil,
                    country: backend.country ?? ""
                )
                merged.append(mapped)
            }
        }
        vineyardRepo.saveAll(merged)
        vineyards = merged

        if selectedVineyardId == nil, let first = merged.first {
            selectedVineyardId = first.id
            persistence.save(SelectedVineyardWrapper(id: first.id), key: Keys.selectedVineyardId)
        } else if let id = selectedVineyardId, !merged.contains(where: { $0.id == id }) {
            selectedVineyardId = merged.first?.id
            if let id = selectedVineyardId {
                persistence.save(SelectedVineyardWrapper(id: id), key: Keys.selectedVineyardId)
            } else {
                persistence.remove(key: Keys.selectedVineyardId)
            }
        }

        reloadCurrentVineyardData()
    }

    // MARK: - Pin CRUD

    func addPin(_ pin: VinePin) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = pin
        item.vineyardId = vineyardId
        pins.append(item)
        pinRepo.saveSlice(pins, for: vineyardId)
        onPinChanged?(item.id)
    }

    func updatePin(_ pin: VinePin) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = pins.firstIndex(where: { $0.id == pin.id }) else { return }
        pins[index] = pin
        pinRepo.saveSlice(pins, for: vineyardId)
        onPinChanged?(pin.id)
    }

    func deletePin(_ pinId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        pins.removeAll { $0.id == pinId }
        pinRepo.saveSlice(pins, for: vineyardId)
        onPinDeleted?(pinId)
    }

    func togglePinCompletion(_ pinId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = pins.firstIndex(where: { $0.id == pinId }) else { return }
        var pin = pins[index]
        pin.isCompleted.toggle()
        pin.completedAt = pin.isCompleted ? Date() : nil
        pins[index] = pin
        pinRepo.saveSlice(pins, for: vineyardId)
        onPinChanged?(pinId)
    }

    /// Apply a pin upsert that originated from a remote sync pull. Does NOT
    /// trigger `onPinChanged` (avoids re-marking the pin dirty).
    func applyRemotePinUpsert(_ pin: VinePin) {
        guard let vineyardId = selectedVineyardId, pin.vineyardId == vineyardId else {
            // Still persist into the appropriate slice on disk so it surfaces
            // when the user switches vineyards.
            var allPins = pinRepo.loadAll()
            if let idx = allPins.firstIndex(where: { $0.id == pin.id }) {
                allPins[idx] = pin
            } else {
                allPins.append(pin)
            }
            pinRepo.replace(allPins.filter { $0.vineyardId == pin.vineyardId }, for: pin.vineyardId)
            return
        }
        if let idx = pins.firstIndex(where: { $0.id == pin.id }) {
            pins[idx] = pin
        } else {
            pins.append(pin)
        }
        pinRepo.saveSlice(pins, for: vineyardId)
    }

    /// Apply a pin deletion that originated from a remote sync pull.
    func applyRemotePinDelete(_ pinId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        pins.removeAll { $0.id == pinId }
        pinRepo.saveSlice(pins, for: vineyardId)
    }

    // MARK: - Paddock CRUD

    private func savePaddocksToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [Paddock] = persistence.load(key: Keys.paddocks) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: paddocks)
        persistence.save(all, key: Keys.paddocks)
    }

    func addPaddock(_ paddock: Paddock) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = paddock
        item.vineyardId = vineyardId
        paddocks.append(item)
        savePaddocksToDisk()
        onPaddockChanged?(item.id)
    }

    func updatePaddock(_ paddock: Paddock) {
        guard let index = paddocks.firstIndex(where: { $0.id == paddock.id }) else { return }
        paddocks[index] = paddock
        savePaddocksToDisk()
        onPaddockChanged?(paddock.id)
    }

    func deletePaddock(_ paddockId: UUID) {
        paddocks.removeAll { $0.id == paddockId }
        savePaddocksToDisk()
        onPaddockDeleted?(paddockId)
    }

    /// Apply a paddock upsert that originated from a remote sync pull. Does NOT
    /// trigger `onPaddockChanged` (avoids re-marking the paddock dirty).
    func applyRemotePaddockUpsert(_ paddock: Paddock) {
        if selectedVineyardId == paddock.vineyardId {
            if let idx = paddocks.firstIndex(where: { $0.id == paddock.id }) {
                paddocks[idx] = paddock
            } else {
                paddocks.append(paddock)
            }
            savePaddocksToDisk()
        } else {
            // Persist into the on-disk slice so it surfaces when switching vineyards.
            var all: [Paddock] = persistence.load(key: Keys.paddocks) ?? []
            if let idx = all.firstIndex(where: { $0.id == paddock.id }) {
                all[idx] = paddock
            } else {
                all.append(paddock)
            }
            persistence.save(all, key: Keys.paddocks)
        }
    }

    /// Apply a paddock deletion that originated from a remote sync pull.
    func applyRemotePaddockDelete(_ paddockId: UUID) {
        paddocks.removeAll { $0.id == paddockId }
        if selectedVineyardId != nil {
            savePaddocksToDisk()
        } else {
            var all: [Paddock] = persistence.load(key: Keys.paddocks) ?? []
            all.removeAll { $0.id == paddockId }
            persistence.save(all, key: Keys.paddocks)
        }
    }

    // MARK: - Trip CRUD

    func startTrip(_ trip: Trip) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = trip
        item.vineyardId = vineyardId
        item.isActive = true
        trips.append(item)
        tripRepo.saveSlice(trips, for: vineyardId)
        onTripChanged?(item.id)
    }

    func updateTrip(_ trip: Trip) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
        tripRepo.saveSlice(trips, for: vineyardId)
        onTripChanged?(trip.id)
    }

    func endTrip(_ tripId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = trips.firstIndex(where: { $0.id == tripId }) else { return }
        var trip = trips[index]
        trip.isActive = false
        trip.endTime = Date()
        trips[index] = trip
        tripRepo.saveSlice(trips, for: vineyardId)
        onTripChanged?(tripId)
    }

    func deleteTrip(_ tripId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        trips.removeAll { $0.id == tripId }
        tripRepo.saveSlice(trips, for: vineyardId)
        onTripDeleted?(tripId)
    }

    /// Apply a trip upsert that originated from a remote sync pull. Does NOT
    /// trigger `onTripChanged` (avoids re-marking the trip dirty).
    func applyRemoteTripUpsert(_ trip: Trip) {
        if selectedVineyardId == trip.vineyardId {
            if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[idx] = trip
            } else {
                trips.append(trip)
            }
            if let vineyardId = selectedVineyardId {
                tripRepo.saveSlice(trips, for: vineyardId)
            }
        } else {
            // Persist into the on-disk slice for the trip's vineyard so it
            // surfaces when switching vineyards.
            var all = tripRepo.loadAll()
            if let idx = all.firstIndex(where: { $0.id == trip.id }) {
                all[idx] = trip
            } else {
                all.append(trip)
            }
            tripRepo.replace(all.filter { $0.vineyardId == trip.vineyardId }, for: trip.vineyardId)
        }
    }

    /// Apply a trip deletion that originated from a remote sync pull.
    func applyRemoteTripDelete(_ tripId: UUID) {
        if let vineyardId = selectedVineyardId {
            trips.removeAll { $0.id == tripId }
            tripRepo.saveSlice(trips, for: vineyardId)
        }
        var all = tripRepo.loadAll()
        if let removed = all.first(where: { $0.id == tripId }) {
            all.removeAll { $0.id == tripId }
            tripRepo.replace(all.filter { $0.vineyardId == removed.vineyardId }, for: removed.vineyardId)
        }
    }

    // MARK: - SprayRecord CRUD

    func addSprayRecord(_ record: SprayRecord) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = record
        item.vineyardId = vineyardId
        sprayRecords.append(item)
        sprayRepo.saveRecordsSlice(sprayRecords, for: vineyardId)
    }

    func updateSprayRecord(_ record: SprayRecord) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = sprayRecords.firstIndex(where: { $0.id == record.id }) else { return }
        sprayRecords[index] = record
        sprayRepo.saveRecordsSlice(sprayRecords, for: vineyardId)
    }

    func deleteSprayRecord(_ recordId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        sprayRecords.removeAll { $0.id == recordId }
        sprayRepo.saveRecordsSlice(sprayRecords, for: vineyardId)
    }

    // MARK: - MaintenanceLog CRUD

    func addMaintenanceLog(_ log: MaintenanceLog) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = log
        item.vineyardId = vineyardId
        maintenanceLogs.append(item)
        maintenanceLogRepo.saveSlice(maintenanceLogs, for: vineyardId)
    }

    func updateMaintenanceLog(_ log: MaintenanceLog) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = maintenanceLogs.firstIndex(where: { $0.id == log.id }) else { return }
        maintenanceLogs[index] = log
        maintenanceLogRepo.saveSlice(maintenanceLogs, for: vineyardId)
    }

    func deleteMaintenanceLog(_ logId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        maintenanceLogs.removeAll { $0.id == logId }
        maintenanceLogRepo.saveSlice(maintenanceLogs, for: vineyardId)
    }

    // MARK: - WorkTask CRUD

    func addWorkTask(_ task: WorkTask) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = task
        item.vineyardId = vineyardId
        workTasks.append(item)
        workTaskRepo.saveSlice(workTasks, for: vineyardId)
    }

    func updateWorkTask(_ task: WorkTask) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let index = workTasks.firstIndex(where: { $0.id == task.id }) else { return }
        workTasks[index] = task
        workTaskRepo.saveSlice(workTasks, for: vineyardId)
    }

    func deleteWorkTask(_ taskId: UUID) {
        guard let vineyardId = selectedVineyardId else { return }
        workTasks.removeAll { $0.id == taskId }
        workTaskRepo.saveSlice(workTasks, for: vineyardId)
    }

    // MARK: - Settings

    func saveSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settingsRepo.upsert(newSettings)
    }
}

private nonisolated struct SelectedVineyardWrapper: Codable, Sendable {
    let id: UUID
}
