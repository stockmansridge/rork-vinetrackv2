import Foundation
import CoreLocation

/// Backend-neutral live trip tracking service. Keeps the active trip in
/// MigratedDataStore.trips (where isActive == true) and appends GPS points to
/// it as the device location updates. Uses when-in-use location only.
@Observable
@MainActor
final class TripTrackingService {

    // MARK: - Published state

    var isTracking: Bool = false
    var isPaused: Bool = false
    var currentDistance: Double = 0
    var elapsedTime: TimeInterval = 0
    var currentSpeed: Double?
    var errorMessage: String?

    // MARK: - Dependencies

    private weak var store: MigratedDataStore?
    private weak var locationService: LocationService?

    private var trackingTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var lastObservedLocation: CLLocation?

    // MARK: - Configuration

    func configure(store: MigratedDataStore, locationService: LocationService) {
        self.store = store
        self.locationService = locationService
        resumeIfNeeded()
    }

    // MARK: - Active trip helpers

    var activeTrip: Trip? {
        store?.trips.first { $0.isActive }
    }

    // MARK: - Start

    func startTrip(
        type: TripType,
        paddockId: UUID?,
        paddockName: String,
        trackingPattern: TrackingPattern = .sequential,
        personName: String = ""
    ) {
        guard let store else { return }
        guard store.selectedVineyardId != nil else {
            errorMessage = "No vineyard selected."
            return
        }
        if activeTrip != nil {
            errorMessage = "A trip is already in progress."
            return
        }

        let trip = Trip(
            paddockId: paddockId,
            paddockName: paddockName,
            paddockIds: paddockId.map { [$0] } ?? [],
            startTime: Date(),
            isActive: true,
            trackingPattern: trackingPattern,
            personName: personName
        )
        store.startTrip(trip)
        errorMessage = nil
        beginTracking()
        _ = type
    }

    // MARK: - Pause / Resume

    func pauseTrip() {
        guard var trip = activeTrip, !trip.isPaused else { return }
        trip.isPaused = true
        trip.pauseTimestamps.append(Date())
        store?.updateTrip(trip)
        isPaused = true
        stopTrackingLoops(stopLocation: false)
    }

    func resumeTrip() {
        guard var trip = activeTrip, trip.isPaused else { return }
        trip.isPaused = false
        trip.resumeTimestamps.append(Date())
        store?.updateTrip(trip)
        isPaused = false
        beginTracking()
    }

    // MARK: - End

    func endTrip() {
        guard let trip = activeTrip else { return }
        store?.endTrip(trip.id)
        stopTrackingLoops(stopLocation: true)
        isTracking = false
        isPaused = false
        currentDistance = 0
        elapsedTime = 0
        currentSpeed = nil
        lastObservedLocation = nil
    }

    // MARK: - Manual point

    func addCurrentLocationPoint() {
        guard let location = locationService?.location else { return }
        appendPoint(from: location, force: true)
    }

    // MARK: - Quick pin during trip

    @discardableResult
    func dropPinDuringTrip(
        button: ButtonConfig,
        paddockId: UUID? = nil,
        rowNumber: Int? = nil,
        side: PinSide = .right,
        notes: String? = nil
    ) -> VinePin? {
        guard let store, let trip = activeTrip else { return nil }
        guard let location = locationService?.location else {
            errorMessage = "Waiting for GPS location."
            return nil
        }
        guard var pin = store.createPinFromButton(
            button: button,
            coordinate: location.coordinate,
            heading: locationService?.heading?.trueHeading ?? 0,
            side: side,
            paddockId: paddockId ?? trip.paddockId,
            rowNumber: rowNumber,
            notes: notes
        ) else { return nil }

        pin.tripId = trip.id
        store.updatePin(pin)

        var updatedTrip = trip
        if !updatedTrip.pinIds.contains(pin.id) {
            updatedTrip.pinIds.append(pin.id)
            store.updateTrip(updatedTrip)
        }
        return pin
    }

    // MARK: - Resume after launch

    func resumeIfNeeded() {
        guard activeTrip != nil, !isTracking else { return }
        if activeTrip?.isPaused == true {
            isPaused = true
            return
        }
        beginTracking()
    }

    // MARK: - Internals

    private func beginTracking() {
        guard let locationService else { return }
        let status = locationService.authorizationStatus
        if status == .notDetermined {
            locationService.requestPermission()
        } else if status == .denied || status == .restricted {
            errorMessage = "Location permission is required to track trips."
            return
        }

        locationService.startUpdating()
        isTracking = true
        isPaused = false
        lastObservedLocation = locationService.location
        if let trip = activeTrip {
            currentDistance = trip.totalDistance
            elapsedTime = trip.activeDuration
        }

        trackingTask?.cancel()
        let interval = max(0.5, store?.settings.rowTrackingInterval ?? 1.0)
        trackingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self else { return }
                if Task.isCancelled { return }
                await MainActor.run {
                    self.sampleAndAppendPoint()
                }
            }
        }

        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if Task.isCancelled { return }
                await MainActor.run {
                    if let trip = self.activeTrip {
                        self.elapsedTime = trip.activeDuration
                    }
                }
            }
        }
    }

    private func stopTrackingLoops(stopLocation: Bool) {
        trackingTask?.cancel()
        trackingTask = nil
        tickerTask?.cancel()
        tickerTask = nil
        if stopLocation {
            locationService?.stopUpdating()
        }
        isTracking = false
    }

    private func sampleAndAppendPoint() {
        guard let location = locationService?.location else { return }
        appendPoint(from: location, force: false)
    }

    private func appendPoint(from location: CLLocation, force: Bool) {
        guard let store, var trip = activeTrip, !trip.isPaused else { return }

        let newPoint = CoordinatePoint(coordinate: location.coordinate)
        if let last = trip.pathPoints.last {
            let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let segment = location.distance(from: lastLocation)
            if !force && segment < 1.0 { return }
            trip.totalDistance += segment
            trip.pathPoints.append(newPoint)
        } else {
            trip.pathPoints.append(newPoint)
        }
        store.updateTrip(trip)
        currentDistance = trip.totalDistance
        currentSpeed = location.speed >= 0 ? location.speed : nil
        lastObservedLocation = location
    }
}
