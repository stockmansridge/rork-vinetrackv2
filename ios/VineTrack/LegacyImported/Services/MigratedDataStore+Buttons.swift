import Foundation
import CoreLocation

extension MigratedDataStore {

    private enum ButtonKeys {
        static let repairButtons = "vinetrack_repair_buttons"
        static let growthButtons = "vinetrack_growth_buttons"
    }

    private var btnPersistence: PersistenceStore { .shared }

    // MARK: - Active button sets

    func updateRepairButtons(_ buttons: [ButtonConfig]) {
        repairButtons = buttons
        btnPersistence.save(repairButtons, key: ButtonKeys.repairButtons)
    }

    func updateGrowthButtons(_ buttons: [ButtonConfig]) {
        growthButtons = buttons
        btnPersistence.save(growthButtons, key: ButtonKeys.growthButtons)
    }

    func resetRepairButtonsToDefault() {
        guard let vineyardId = selectedVineyardId else { return }
        let defaults = ButtonConfig.defaultRepairButtons(for: vineyardId)
        updateRepairButtons(defaults)
    }

    func resetGrowthButtonsToDefault() {
        guard let vineyardId = selectedVineyardId else { return }
        let defaults = ButtonConfig.defaultGrowthButtons(for: vineyardId)
        updateGrowthButtons(defaults)
    }

    // MARK: - Quick pin creation from a button

    /// Create a local VinePin from a button configuration, using the supplied location
    /// (or the most recent device location if available). Persists the pin via `addPin`.
    @discardableResult
    func createPinFromButton(
        button: ButtonConfig,
        coordinate: CLLocationCoordinate2D,
        heading: Double,
        side: PinSide = .right,
        paddockId: UUID? = nil,
        rowNumber: Int? = nil,
        createdBy: String? = nil,
        growthStageCode: String? = nil,
        notes: String? = nil
    ) -> VinePin? {
        guard let vineyardId = selectedVineyardId else { return nil }
        let pin = VinePin(
            vineyardId: vineyardId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            heading: heading,
            buttonName: button.name,
            buttonColor: button.color,
            side: side,
            mode: button.mode,
            paddockId: paddockId,
            rowNumber: rowNumber,
            timestamp: Date(),
            createdBy: createdBy,
            isCompleted: false,
            growthStageCode: growthStageCode,
            notes: notes
        )
        addPin(pin)
        return pin
    }

    /// Create a local growth-stage pin (button mode `.growth` with isGrowthStageButton).
    @discardableResult
    func createGrowthStagePin(
        stageCode: String,
        stageDescription: String,
        coordinate: CLLocationCoordinate2D,
        heading: Double,
        side: PinSide = .right,
        paddockId: UUID? = nil,
        rowNumber: Int? = nil,
        createdBy: String? = nil,
        notes: String? = nil
    ) -> VinePin? {
        guard let vineyardId = selectedVineyardId else { return nil }
        let pin = VinePin(
            vineyardId: vineyardId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            heading: heading,
            buttonName: "EL \(stageCode)",
            buttonColor: "darkgreen",
            side: side,
            mode: .growth,
            paddockId: paddockId,
            rowNumber: rowNumber,
            timestamp: Date(),
            createdBy: createdBy,
            isCompleted: false,
            growthStageCode: stageCode,
            notes: notes ?? stageDescription
        )
        addPin(pin)
        return pin
    }
}
