//
//  WeatherService.swift
//  Isla
//
//  Local weather from Open-Meteo (free, no account, no tracking). Location is
//  rounded to roughly a kilometre before it leaves the Mac.
//

import CoreLocation
import MapKit
import SwiftUI

struct HourForecast: Equatable, Identifiable {
    var date: Date
    var temperature: Double
    var code: Int
    var isDay: Bool

    var id: Date { date }
    var symbol: String { WeatherSnapshot.symbol(for: code, isDay: isDay) }
}

struct WeatherSnapshot: Equatable {
    var temperature: Double
    var apparent: Double
    var high: Double
    var low: Double
    var code: Int
    var isDay: Bool
    var city: String?
    var precipitationChance: Int?
    var updated: Date
    /// The next few hours, starting after the current one.
    var hourly: [HourForecast] = []

    var symbol: String { WeatherSnapshot.symbol(for: code, isDay: isDay) }
    var condition: String { WeatherSnapshot.condition(for: code) }

    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: return "cloud.rain.fill"
        case 65, 67, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func condition(for code: Int) -> String {
        switch code {
        case 0: return String(localized: "Clear")
        case 1: return String(localized: "Mostly Clear")
        case 2: return String(localized: "Partly Cloudy")
        case 3: return String(localized: "Overcast")
        case 45, 48: return String(localized: "Fog")
        case 51, 53, 55: return String(localized: "Drizzle")
        case 56, 57: return String(localized: "Freezing Drizzle")
        case 61, 63, 80, 81: return String(localized: "Rain")
        case 65, 82: return String(localized: "Heavy Rain")
        case 66, 67: return String(localized: "Freezing Rain")
        case 71, 73, 75, 77, 85, 86: return String(localized: "Snow")
        case 95, 96, 99: return String(localized: "Thunderstorm")
        default: return String(localized: "Cloudy")
        }
    }
}

@Observable
@MainActor
final class WeatherService: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    private(set) var snapshot: WeatherSnapshot?
    private(set) var authorization: CLAuthorizationStatus
    private(set) var isLoading = false

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var lastLocation: CLLocation?

    private override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        if authorization == .authorizedAlways || authorization == .authorized {
            manager.requestLocation()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            MainActor.assumeIsolated { WeatherService.shared.refresh() }
        }
    }

    #if DEBUG
    func applyDemo() {
        authorization = .authorizedAlways
        let hour = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        let hourly = [(30, 1), (30, 2), (29, 2), (28, 80)].enumerated().map { index, item in
            HourForecast(date: hour.addingTimeInterval(Double(index + 1) * 3600), temperature: Double(item.0), code: item.1, isDay: true)
        }
        snapshot = WeatherSnapshot(temperature: 29, apparent: 33, high: 31, low: 24, code: 2, isDay: true,
                                   city: "Santo Domingo", precipitationChance: 20, updated: .now, hourly: hourly)
    }
    #endif

    func requestAccess() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func refresh() {
        if let lastLocation {
            Task { await load(for: lastLocation) }
        } else {
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedAlways || status == .authorized { self.manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
            await self.load(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func load(for location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        let latitude = (location.coordinate.latitude * 100).rounded() / 100
        let longitude = (location.coordinate.longitude * 100).rounded() / 100
        let unit = Preferences.shared.temperatureUnit == .fahrenheit ? "fahrenheit" : "celsius"
        let query = "latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,apparent_temperature,weather_code,is_day" +
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=1" +
            "&hourly=temperature_2m,weather_code,is_day&forecast_hours=7&timeformat=unixtime&timezone=auto&temperature_unit=\(unit)"
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?\(query)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let daily = json["daily"] as? [String: Any] else { return }

        var hourly: [HourForecast] = []
        if let block = json["hourly"] as? [String: Any],
           let times = block["time"] as? [Double],
           let temperatures = block["temperature_2m"] as? [Double],
           let codes = block["weather_code"] as? [Int] {
            let days = block["is_day"] as? [Int] ?? []
            for index in times.indices where index < temperatures.count && index < codes.count {
                let date = Date(timeIntervalSince1970: times[index])
                guard date > .now else { continue }
                hourly.append(HourForecast(date: date, temperature: temperatures[index], code: codes[index],
                                           isDay: index < days.count ? days[index] == 1 : true))
            }
        }

        let city = await reverseGeocode(location)
        snapshot = WeatherSnapshot(temperature: current["temperature_2m"] as? Double ?? 0,
                                   apparent: current["apparent_temperature"] as? Double ?? 0,
                                   high: (daily["temperature_2m_max"] as? [Double])?.first ?? 0,
                                   low: (daily["temperature_2m_min"] as? [Double])?.first ?? 0,
                                   code: current["weather_code"] as? Int ?? 3,
                                   isDay: (current["is_day"] as? Int ?? 1) == 1,
                                   city: city ?? snapshot?.city,
                                   precipitationChance: (daily["precipitation_probability_max"] as? [Int])?.first,
                                   updated: .now,
                                   hourly: Array(hourly.prefix(4)))
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        if let city = snapshot?.city, let last = lastLocation, last.distance(from: location) < 5000 { return city }
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return item.addressRepresentations?.cityName ?? item.name
    }
}

struct WeatherCard: View {
    private let weather = WeatherService.shared

    var body: some View {
        IslaCard(padding: 11) {
            if let snapshot = weather.snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").font(.system(size: 9))
                        Text(snapshot.city ?? String(localized: "My Location"))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    HStack(alignment: .center, spacing: 8) {
                        Text("\(Int(snapshot.temperature.rounded()))°")
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                        Image(systemName: snapshot.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 26))
                    }
                    Spacer(minLength: 0)
                    if !snapshot.hourly.isEmpty {
                        HourlyRow(hours: snapshot.hourly)
                        Spacer(minLength: 0)
                    }
                    Text(snapshot.condition)
                        .font(.system(size: 12, weight: .semibold))
                    Text("H:\(Int(snapshot.high.rounded()))°  L:\(Int(snapshot.low.rounded()))°")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    CardHeader(title: "Weather", symbol: "cloud.sun.fill", tint: .cyan)
                    Spacer(minLength: 0)
                    if weather.authorization == .notDetermined {
                        Text("See local weather at a glance.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                        Button("Use My Location") { weather.requestAccess() }
                            .buttonStyle(NotchPillButtonStyle())
                    } else if weather.authorization == .denied || weather.authorization == .restricted {
                        Text("Location is off for Isla.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                        Button("Open Settings") { SystemSettings.open("Privacy_LocationServices") }
                            .buttonStyle(NotchPillButtonStyle())
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// The next hours under the current temperature, like the system Weather widget.
private struct HourlyRow: View {
    let hours: [HourForecast]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(hours) { hour in
                VStack(spacing: 3) {
                    Text(hour.date, format: .dateTime.hour())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: hour.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 13))
                        .frame(height: 16)
                    Text("\(Int(hour.temperature.rounded()))°")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

