import Foundation

extension MigratedDataStore {

    // MARK: - Convenience accessors used by imported spray views

    var seasonFuelCostPerLitre: Double {
        settings.seasonFuelCostPerLitre
    }

    func operatorCategoryForName(_ name: String) -> OperatorCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return operatorCategories.first { $0.name.lowercased() == trimmed.lowercased() }
    }

    // MARK: - SprayRecord overload

    func deleteSprayRecord(_ record: SprayRecord) {
        deleteSprayRecord(record.id)
    }

    // MARK: - Saved chemicals

    func addSavedChemical(_ chemical: SavedChemical) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = chemical
        item.vineyardId = vineyardId
        savedChemicals.append(item)
        sprayRepo.saveChemicalsSlice(savedChemicals, for: vineyardId)
    }

    func updateSavedChemical(_ chemical: SavedChemical) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let idx = savedChemicals.firstIndex(where: { $0.id == chemical.id }) else { return }
        savedChemicals[idx] = chemical
        sprayRepo.saveChemicalsSlice(savedChemicals, for: vineyardId)
    }

    func deleteSavedChemical(_ chemical: SavedChemical) {
        guard let vineyardId = selectedVineyardId else { return }
        savedChemicals.removeAll { $0.id == chemical.id }
        sprayRepo.saveChemicalsSlice(savedChemicals, for: vineyardId)
    }

    // MARK: - Saved spray presets

    func addSavedSprayPreset(_ preset: SavedSprayPreset) {
        guard let vineyardId = selectedVineyardId else { return }
        var item = preset
        item.vineyardId = vineyardId
        savedSprayPresets.append(item)
        sprayRepo.savePresetsSlice(savedSprayPresets, for: vineyardId)
    }

    func updateSavedSprayPreset(_ preset: SavedSprayPreset) {
        guard let vineyardId = selectedVineyardId else { return }
        guard let idx = savedSprayPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        savedSprayPresets[idx] = preset
        sprayRepo.savePresetsSlice(savedSprayPresets, for: vineyardId)
    }

    func deleteSavedSprayPreset(_ preset: SavedSprayPreset) {
        guard let vineyardId = selectedVineyardId else { return }
        savedSprayPresets.removeAll { $0.id == preset.id }
        sprayRepo.savePresetsSlice(savedSprayPresets, for: vineyardId)
    }

    // MARK: - Equipment options (autocomplete entries)

    func equipmentOptions(for category: String) -> [SavedEquipmentOption] {
        savedEquipmentOptions
            .filter { $0.category == category }
            .sorted { $0.value.lowercased() < $1.value.lowercased() }
    }

    func addEquipmentOption(_ option: SavedEquipmentOption) {
        guard let vineyardId = selectedVineyardId else { return }
        let trimmed = option.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if savedEquipmentOptions.contains(where: {
            $0.category == option.category && $0.value.lowercased() == trimmed.lowercased()
        }) {
            return
        }
        var item = option
        item.vineyardId = vineyardId
        item.value = trimmed
        savedEquipmentOptions.append(item)
        sprayRepo.saveEquipmentOptionsSlice(savedEquipmentOptions, for: vineyardId)
    }

    func deleteEquipmentOption(_ option: SavedEquipmentOption) {
        guard let vineyardId = selectedVineyardId else { return }
        savedEquipmentOptions.removeAll { $0.id == option.id }
        sprayRepo.saveEquipmentOptionsSlice(savedEquipmentOptions, for: vineyardId)
    }
}
