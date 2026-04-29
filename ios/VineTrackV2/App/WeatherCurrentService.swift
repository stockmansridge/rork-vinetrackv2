import Foundation
import CoreLocation

/// Backend-safe current-weather fetcher.
///
/// Fetches a current weather snapshot for spray jobs using the Weather
/// Underground PWS API. Long-term this should move behind a Supabase
/// Edge Function (so the API key never ships in the app); for now it
/// reads `AppConfig.wundergroundAPIKey`, mirroring the existing
/// `DegreeDayService` pattern.
///
/// Strategy:
/// 1. If a `stationId` is supplied (e.g. from `AppSettings.weatherStationId`),
///    fetch current observations directly.
/// 2. Otherwise, look up the nearest PWS station to the given coordinate
///    and use that.
nonisolated struct WeatherCurrentService: Sendable {

    nonisolated struct Snapshot: Sendable {
        let temperatureC: Double?
        let windSpeedKmh: Double?
        let windDirection: String
        let humidityPercent: Double?
        let observedAt: Date
        let stationId: String?
        let source: String
    }

    nonisolated enum WeatherFetchError: Error, LocalizedError, Sendable {
        case missingAPIKey
        case noNearbyStation
        case noObservations
        case network(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Weather Underground API key not configured. Add a key in settings to enable automatic weather."
            case .noNearbyStation:
                return "No nearby weather station found. Enter weather manually."
            case .noObservations:
                return "No current observations returned. Try again or enter weather manually."
            case .network(let m):
                return "Weather fetch failed: \(m)"
            }
        }
    }

    func fetch(coordinate: CLLocationCoordinate2D, stationId: String? = nil) async throws -> Snapshot {
        let apiKey = AppConfig.wundergroundAPIKey
        guard !apiKey.isEmpty else { throw WeatherFetchError.missingAPIKey }

        let resolvedStation: String
        if let stationId, !stationId.isEmpty {
            resolvedStation = stationId
        } else {
            resolvedStation = try await nearestStationId(coordinate: coordinate, apiKey: apiKey)
        }

        return try await currentObservation(stationId: resolvedStation, apiKey: apiKey)
    }

    private func nearestStationId(coordinate: CLLocationCoordinate2D, apiKey: String) async throws -> String {
        let lat = String(format: "%.5f", coordinate.latitude)
        let lon = String(format: "%.5f", coordinate.longitude)
        let urlString = "https://api.weather.com/v3/location/near?geocode=\(lat),\(lon)&product=pws&format=json&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw WeatherFetchError.network("Invalid URL") }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw WeatherFetchError.network("No HTTP response") }
        if http.statusCode == 204 { throw WeatherFetchError.noNearbyStation }
        guard http.statusCode == 200 else {
            throw WeatherFetchError.network("HTTP \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let location = json["location"] as? [String: Any],
              let stations = location["stationId"] as? [String],
              let first = stations.first else {
            throw WeatherFetchError.noNearbyStation
        }
        return first
    }

    private func currentObservation(stationId: String, apiKey: String) async throws -> Snapshot {
        let urlString = "https://api.weather.com/v2/pws/observations/current?stationId=\(stationId)&format=json&units=m&numericPrecision=decimal&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw WeatherFetchError.network("Invalid URL") }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw WeatherFetchError.network("No HTTP response") }
        if http.statusCode == 204 { throw WeatherFetchError.noObservations }
        guard http.statusCode == 200 else {
            throw WeatherFetchError.network("HTTP \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let observations = json["observations"] as? [[String: Any]],
              let obs = observations.first else {
            throw WeatherFetchError.noObservations
        }

        let metric = (obs["metric"] as? [String: Any]) ?? [:]
        let temp = parseDouble(metric["temp"]) ?? parseDouble(obs["temp"])
        let wind = parseDouble(metric["windSpeed"]) ?? parseDouble(obs["windSpeed"])
        let humidity = parseDouble(obs["humidity"]) ?? parseDouble(metric["humidity"])
        let winddirDeg = parseDouble(obs["winddir"]) ?? parseDouble(metric["winddir"])
        let direction = winddirDeg.map { Self.compassDirection(degrees: $0) } ?? ""

        let observedAt: Date = {
            if let s = obs["obsTimeUtc"] as? String,
               let d = ISO8601DateFormatter().date(from: s) {
                return d
            }
            return Date()
        }()

        return Snapshot(
            temperatureC: temp,
            windSpeedKmh: wind,
            windDirection: direction,
            humidityPercent: humidity,
            observedAt: observedAt,
            stationId: stationId,
            source: "Weather Underground PWS"
        )
    }

    private func parseDouble(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }

    static func compassDirection(degrees: Double) -> String {
        let dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int((normalized / 22.5).rounded()) % 16
        return dirs[idx]
    }
}
