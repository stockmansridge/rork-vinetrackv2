import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var location: CLLocation?
    var heading: CLHeading?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isUsingMockLocation: Bool = false
    private var isBackgroundTracking: Bool = false
    private var mockFallbackTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 5
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        scheduleSimulatorMockFallback()
    }

    private func scheduleSimulatorMockFallback() {
        #if targetEnvironment(simulator)
        mockFallbackTask?.cancel()
        mockFallbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            if self.location == nil {
                let mock = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: -41.2865, longitude: 174.7762),
                    altitude: 0,
                    horizontalAccuracy: 10,
                    verticalAccuracy: 10,
                    timestamp: Date()
                )
                self.location = mock
                self.isUsingMockLocation = true
            }
        }
        #endif
    }

    func stopUpdating() {
        if !isBackgroundTracking {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
        }
    }

    func startBackgroundUpdating() {
        isBackgroundTracking = true
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        if authorizationStatus == .authorizedWhenInUse {
            requestAlwaysPermission()
        }
    }

    func stopBackgroundUpdating() {
        isBackgroundTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            self.location = last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.heading = newHeading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
