//
//  Converter.swift
//  Isla
//
//  The launcher's conversions: "10 km to mi", "70 f en c", "2 tazas a ml", "1.5 gb in mb",
//  and currencies ("100 usd a dop"). Units are converted on the Mac with Foundation;
//  exchange rates are fetched only when you type a currency conversion, at most twice a
//  day, from ExchangeRate-API's open endpoint (no account, only the base currency is sent).
//

import Foundation

struct Conversion: Equatable {
    var amount: Double
    var from: String
    var result: Double
    var to: String
    /// Where the number comes from, for currencies.
    var source: String?
}

enum Converter {
    // MARK: Parsing

    struct Request: Equatable {
        var amount: Double
        var from: String
        var to: String
    }

    private static let joiners: Set<String> = ["to", "in", "en", "a", "->", "→", "=", "as", "into"]

    /// "10 km to mi" → (10, "km", "mi"). Also "10km en millas", "$100 a dop".
    static func parse(_ input: String) -> Request? {
        var text = input.lowercased().trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "$", with: "usd ").replacingOccurrences(of: "€", with: "eur ")
        // Split "10km" into "10 km".
        var spaced = ""
        var previous: Character?
        for char in text {
            if let previous, previous.isNumber, char.isLetter || char == "°" { spaced.append(" ") }
            spaced.append(char)
            previous = char
        }
        var words = spaced.split(whereSeparator: { $0 == " " }).map(String.init)
        guard words.count >= 3 else { return nil }
        // The amount, wherever the currency word put it ("usd 100 a dop").
        guard let amountIndex = words.firstIndex(where: { number($0) != nil }), let amount = number(words[amountIndex]) else { return nil }
        words.remove(at: amountIndex)
        // "in" is both a joiner and a unit ("10 in to cm"): prefer the split whose two sides
        // are both known units or currencies.
        let candidates = words.indices.filter { joiners.contains(words[$0]) && $0 > 0 && $0 < words.count - 1 }
        func sides(_ index: Int) -> (String, String) {
            (words[..<index].joined(separator: " "), words[(index + 1)...].joined(separator: " "))
        }
        func known(_ word: String) -> Bool { units[word] != nil || currencyCode(word) != nil }
        guard let joinIndex = candidates.first(where: { known(sides($0).0) && known(sides($0).1) }) ?? candidates.first else { return nil }
        let (from, to) = sides(joinIndex)
        return Request(amount: amount, from: from, to: to)
    }

    private static func number(_ word: String) -> Double? {
        var text = word
        if text.contains(","), !text.contains(".") { text = text.replacingOccurrences(of: ",", with: ".") }
        text = text.replacingOccurrences(of: ",", with: "")
        return Double(text)
    }

    // MARK: Units

    private static let units: [String: Dimension] = {
        var map: [String: Dimension] = [:]
        func add(_ unit: Dimension, _ names: String...) { names.forEach { map[$0] = unit } }
        // Length
        add(UnitLength.millimeters, "mm", "milimetro", "milímetro", "milimetros", "milímetros", "millimeter", "millimeters")
        add(UnitLength.centimeters, "cm", "centimetro", "centímetro", "centimetros", "centímetros", "centimeter", "centimeters")
        add(UnitLength.meters, "m", "metro", "metros", "meter", "meters", "metre", "metres")
        add(UnitLength.kilometers, "km", "kilometro", "kilómetro", "kilometros", "kilómetros", "kilometer", "kilometers")
        add(UnitLength.inches, "in", "inch", "inches", "pulgada", "pulgadas", "\"")
        add(UnitLength.feet, "ft", "foot", "feet", "pie", "pies")
        add(UnitLength.yards, "yd", "yard", "yards", "yarda", "yardas")
        add(UnitLength.miles, "mi", "mile", "miles", "milla", "millas")
        add(UnitLength.nauticalMiles, "nmi", "milla nautica", "millas nauticas", "millas náuticas")
        // Mass
        add(UnitMass.milligrams, "mg", "miligramo", "miligramos", "milligram", "milligrams")
        add(UnitMass.grams, "g", "gr", "gramo", "gramos", "gram", "grams")
        add(UnitMass.kilograms, "kg", "kilo", "kilos", "kilogramo", "kilogramos", "kilogram", "kilograms")
        add(UnitMass.ounces, "oz", "onza", "onzas", "ounce", "ounces")
        add(UnitMass.pounds, "lb", "lbs", "libra", "libras", "pound", "pounds")
        add(UnitMass.stones, "st", "stone", "stones")
        add(UnitMass.metricTons, "t", "ton", "tons", "tonelada", "toneladas", "tonne", "tonnes")
        // Temperature
        add(UnitTemperature.celsius, "c", "°c", "celsius", "centigrados", "centígrados")
        add(UnitTemperature.fahrenheit, "f", "°f", "fahrenheit")
        add(UnitTemperature.kelvin, "k", "kelvin")
        // Volume
        add(UnitVolume.milliliters, "ml", "mililitro", "mililitros", "milliliter", "milliliters")
        add(UnitVolume.liters, "l", "lt", "litro", "litros", "liter", "liters", "litre", "litres")
        add(UnitVolume.cups, "cup", "cups", "taza", "tazas")
        add(UnitVolume.tablespoons, "tbsp", "cucharada", "cucharadas", "tablespoon", "tablespoons")
        add(UnitVolume.teaspoons, "tsp", "cucharadita", "cucharaditas", "teaspoon", "teaspoons")
        add(UnitVolume.fluidOunces, "fl oz", "floz", "fluid ounce", "fluid ounces")
        add(UnitVolume.gallons, "gal", "galon", "galón", "galones", "gallon", "gallons")
        add(UnitVolume.pints, "pt", "pint", "pints", "pinta", "pintas")
        // Speed
        add(UnitSpeed.kilometersPerHour, "km/h", "kmh", "kph")
        add(UnitSpeed.milesPerHour, "mph", "mi/h")
        add(UnitSpeed.metersPerSecond, "m/s")
        add(UnitSpeed.knots, "kn", "kt", "knot", "knots", "nudo", "nudos")
        // Area
        add(UnitArea.squareMeters, "m2", "m²", "metro cuadrado", "metros cuadrados")
        add(UnitArea.squareKilometers, "km2", "km²")
        add(UnitArea.squareFeet, "ft2", "ft²", "sq ft", "pie cuadrado", "pies cuadrados")
        add(UnitArea.acres, "acre", "acres")
        add(UnitArea.hectares, "ha", "hectarea", "hectárea", "hectareas", "hectáreas", "hectare", "hectares")
        // Data
        add(UnitInformationStorage.bytes, "b", "byte", "bytes")
        add(UnitInformationStorage.kilobytes, "kb", "kilobyte", "kilobytes")
        add(UnitInformationStorage.megabytes, "mb", "megabyte", "megabytes")
        add(UnitInformationStorage.gigabytes, "gb", "gigabyte", "gigabytes")
        add(UnitInformationStorage.terabytes, "tb", "terabyte", "terabytes")
        // Time
        add(UnitDuration.seconds, "s", "sec", "secs", "segundo", "segundos", "second", "seconds")
        add(UnitDuration.minutes, "min", "mins", "minuto", "minutos", "minute", "minutes")
        add(UnitDuration.hours, "h", "hr", "hrs", "hora", "horas", "hour", "hours")
        return map
    }()

    /// A unit conversion worked out on the Mac, or nil when the words are not units of the
    /// same kind.
    static func convertUnits(_ request: Request) -> Conversion? {
        guard let from = units[request.from], let to = units[request.to], type(of: from) == type(of: to) else { return nil }
        let value = Measurement(value: request.amount, unit: from).converted(to: to).value
        guard value.isFinite else { return nil }
        return Conversion(amount: request.amount, from: from.symbol, result: value, to: to.symbol, source: nil)
    }

    // MARK: Currencies

    private static let currencyWords: [String: String] = [
        "dolar": "USD", "dólar": "USD", "dolares": "USD", "dólares": "USD", "dollar": "USD", "dollars": "USD", "us$": "USD",
        "euro": "EUR", "euros": "EUR",
        "peso dominicano": "DOP", "pesos dominicanos": "DOP", "rd$": "DOP", "rd": "DOP",
        "peso mexicano": "MXN", "pesos mexicanos": "MXN",
        "libra esterlina": "GBP", "libras esterlinas": "GBP", "pound sterling": "GBP",
        "yen": "JPY", "yenes": "JPY", "yuan": "CNY", "real": "BRL", "reales": "BRL",
        "franco suizo": "CHF", "bitcoin": "BTC",
    ]

    static func currencyCode(_ word: String) -> String? {
        if let code = currencyWords[word] { return code }
        let upper = word.uppercased()
        guard upper.count == 3, upper.allSatisfy(\.isLetter), Locale.commonISOCurrencyCodes.contains(upper) else { return nil }
        return upper
    }

    static func isCurrency(_ request: Request) -> Bool {
        currencyCode(request.from) != nil && currencyCode(request.to) != nil
    }

    private static let ratesKey = "launcherRates"
    private static let ratesDateKey = "launcherRatesDate"

    /// Rates against the US dollar, cached for twelve hours.
    static func rates() async -> [String: Double]? {
        let defaults = UserDefaults.standard
        if let saved = defaults.dictionary(forKey: ratesKey) as? [String: Double],
           let date = defaults.object(forKey: ratesDateKey) as? Date, Date.now.timeIntervalSince(date) < 12 * 3600 {
            return saved
        }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("Isla", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = object["rates"] as? [String: Double], !rates.isEmpty else {
            return defaults.dictionary(forKey: ratesKey) as? [String: Double]
        }
        defaults.set(rates, forKey: ratesKey)
        defaults.set(Date.now, forKey: ratesDateKey)
        return rates
    }

    static func convertCurrency(_ request: Request) async -> Conversion? {
        guard let from = currencyCode(request.from), let to = currencyCode(request.to),
              let rates = await rates(), let fromRate = rates[from], let toRate = rates[to], fromRate > 0 else { return nil }
        let value = request.amount / fromRate * toRate
        return Conversion(amount: request.amount, from: from, result: value, to: to, source: "ExchangeRate-API")
    }
}
