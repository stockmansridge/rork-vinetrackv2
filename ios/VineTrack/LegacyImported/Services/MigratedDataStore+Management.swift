import Foundation

extension MigratedDataStore {

    // MARK: - Persistence keys (mirrors private keys in MigratedDataStore.swift)

    private enum MgmtKeys {
        static let paddocks = "vinetrack_paddocks"
        static let tractors = "vinetrack_tractors"
        static let fuelPurchases = "vinetrack_fuel_purchases"
        static let operatorCategories = "vinetrack_operator_categories"
        static let buttonTemplates = "vinetrack_button_templates"
        static let grapeVarieties = "vinetrack_grape_varieties"
    }

    private var persistenceStore: PersistenceStore { .shared }

    // MARK: - Spray Equipment

    func addSprayEquipment(_ item: SprayEquipmentItem) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = item
        entry.vineyardId = vineyardId
        sprayEquipment.append(entry)
        sprayRepo.saveEquipmentSlice(sprayEquipment, for: vineyardId)
    }

    func updateSprayEquipment(_ item: SprayEquipmentItem) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let idx = sprayEquipment.firstIndex(where: { $0.id == item.id }) else { return }
        sprayEquipment[idx] = item
        sprayRepo.saveEquipmentSlice(sprayEquipment, for: vineyardId)
    }

    func deleteSprayEquipment(_ item: SprayEquipmentItem) {
        guard let vineyardId = selectedVineyardId else { return }
        sprayEquipment.removeAll { $0.id == item.id }
        sprayRepo.saveEquipmentSlice(sprayEquipment, for: vineyardId)
    }

    // MARK: - Tractors

    private func saveTractorsToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [Tractor] = persistenceStore.load(key: MgmtKeys.tractors) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: tractors)
        persistenceStore.save(all, key: MgmtKeys.tractors)
    }

    func addTractor(_ tractor: Tractor) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = tractor
        entry.vineyardId = vineyardId
        tractors.append(entry)
        saveTractorsToDisk()
    }

    func updateTractor(_ tractor: Tractor) {
        guard let idx = tractors.firstIndex(where: { $0.id == tractor.id }) else { return }
        tractors[idx] = tractor
        saveTractorsToDisk()
    }

    func deleteTractor(_ tractor: Tractor) {
        tractors.removeAll { $0.id == tractor.id }
        saveTractorsToDisk()
    }

    // MARK: - Fuel Purchases

    private func saveFuelPurchasesToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [FuelPurchase] = persistenceStore.load(key: MgmtKeys.fuelPurchases) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: fuelPurchases)
        persistenceStore.save(all, key: MgmtKeys.fuelPurchases)
    }

    func addFuelPurchase(_ purchase: FuelPurchase) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = purchase
        entry.vineyardId = vineyardId
        fuelPurchases.append(entry)
        saveFuelPurchasesToDisk()
    }

    func updateFuelPurchase(_ purchase: FuelPurchase) {
        guard let idx = fuelPurchases.firstIndex(where: { $0.id == purchase.id }) else { return }
        fuelPurchases[idx] = purchase
        saveFuelPurchasesToDisk()
    }

    func deleteFuelPurchase(_ purchase: FuelPurchase) {
        fuelPurchases.removeAll { $0.id == purchase.id }
        saveFuelPurchasesToDisk()
    }

    // MARK: - Operator Categories

    private func saveOperatorCategoriesToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [OperatorCategory] = persistenceStore.load(key: MgmtKeys.operatorCategories) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: operatorCategories)
        persistenceStore.save(all, key: MgmtKeys.operatorCategories)
    }

    func addOperatorCategory(_ category: OperatorCategory) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = category
        entry.vineyardId = vineyardId
        operatorCategories.append(entry)
        saveOperatorCategoriesToDisk()
    }

    func updateOperatorCategory(_ category: OperatorCategory) {
        guard let idx = operatorCategories.firstIndex(where: { $0.id == category.id }) else { return }
        operatorCategories[idx] = category
        saveOperatorCategoriesToDisk()
    }

    func deleteOperatorCategory(_ category: OperatorCategory) {
        operatorCategories.removeAll { $0.id == category.id }
        saveOperatorCategoriesToDisk()
    }

    // MARK: - Grape Varieties (CRUD)

    private func saveGrapeVarietiesToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [GrapeVariety] = persistenceStore.load(key: MgmtKeys.grapeVarieties) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: grapeVarieties)
        persistenceStore.save(all, key: MgmtKeys.grapeVarieties)
    }

    func addGrapeVariety(_ variety: GrapeVariety) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = variety
        entry.vineyardId = vineyardId
        grapeVarieties.append(entry)
        saveGrapeVarietiesToDisk()
    }

    func updateGrapeVariety(_ variety: GrapeVariety) {
        guard let idx = grapeVarieties.firstIndex(where: { $0.id == variety.id }) else { return }
        grapeVarieties[idx] = variety
        saveGrapeVarietiesToDisk()
    }

    func deleteGrapeVariety(_ variety: GrapeVariety) {
        grapeVarieties.removeAll { $0.id == variety.id }
        saveGrapeVarietiesToDisk()
    }

    // MARK: - Button Templates

    private func saveButtonTemplatesToDisk() {
        guard let vineyardId = selectedVineyardId else { return }
        var all: [ButtonTemplate] = persistenceStore.load(key: MgmtKeys.buttonTemplates) ?? []
        all.removeAll { $0.vineyardId == vineyardId }
        all.append(contentsOf: buttonTemplates)
        persistenceStore.save(all, key: MgmtKeys.buttonTemplates)
    }

    func buttonTemplates(for mode: PinMode) -> [ButtonTemplate] {
        buttonTemplates.filter { $0.mode == mode }
    }

    func addButtonTemplate(_ template: ButtonTemplate) {
        guard let vineyardId = selectedVineyardId else { return }
        var entry = template
        entry.vineyardId = vineyardId
        buttonTemplates.append(entry)
        saveButtonTemplatesToDisk()
    }

    func updateButtonTemplate(_ template: ButtonTemplate) {
        guard let idx = buttonTemplates.firstIndex(where: { $0.id == template.id }) else { return }
        buttonTemplates[idx] = template
        saveButtonTemplatesToDisk()
    }

    func deleteButtonTemplate(_ template: ButtonTemplate) {
        buttonTemplates.removeAll { $0.id == template.id }
        saveButtonTemplatesToDisk()
    }

    /// Apply a template to the active button set for its mode, replacing existing buttons.
    func applyButtonTemplate(_ template: ButtonTemplate) {
        guard let vineyardId = selectedVineyardId else { return }
        let configs = template.toButtonConfigs(for: vineyardId)
        switch template.mode {
        case .repairs:
            repairButtons = configs
            persistenceStore.save(repairButtons, key: "vinetrack_repair_buttons")
        case .growth:
            growthButtons = configs
            persistenceStore.save(growthButtons, key: "vinetrack_growth_buttons")
        }
    }

    // MARK: - Vineyard update (used by operator-category user assignment)

    func updateVineyard(_ vineyard: Vineyard) {
        vineyards = vineyardRepo.upsert(vineyard)
    }
}
