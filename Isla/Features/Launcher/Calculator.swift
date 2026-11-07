//
//  Calculator.swift
//  Isla
//
//  The launcher's calculator: a small parser of its own, so a stray character can never
//  bring Isla down (NSExpression raises Objective-C exceptions Swift cannot catch).
//  Understands + − × ÷ ^ %, parentheses, a decimal comma or point, pi, e and a few
//  functions: sqrt, cbrt, abs, round, floor, ceil, ln, log, sin, cos, tan.
//

import Foundation

enum Calculator {
    /// The value of `input`, or nil when it is not a calculation (a plain number on its own
    /// is not one: there is nothing to work out).
    static func evaluate(_ input: String) -> Double? {
        var text = input.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("=") { text.removeFirst() }
        guard !text.isEmpty, text.count < 200 else { return nil }
        // A decimal comma ("3,5 * 2") when there is no point in the expression.
        if text.contains(","), !text.contains(".") { text = text.replacingOccurrences(of: ",", with: ".") }
        var parser = Parser(Array(text.lowercased()))
        guard let value = parser.parseExpression(), parser.atEnd, parser.didWork, value.isFinite else { return nil }
        return value
    }

    /// "1234.5" → "1,234.5" in the user's locale. `fraction` caps the decimals (conversions
    /// read better with a few).
    static func format(_ value: Double, fraction: Int = 8) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = abs(value) >= 1e15 || (abs(value) < 1e-6 && value != 0)
        if formatter.usesSignificantDigits {
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 8
        } else {
            formatter.maximumFractionDigits = abs(value) >= 1000 ? 2 : (abs(value) < 0.01 ? 8 : fraction)
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// The same value written plainly, to paste anywhere ("1234.5").
    static func plain(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        var text = String(format: "%.10g", value)
        if text.contains("e") { return text }
        while text.contains("."), text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private struct Parser {
        let chars: [Character]
        var index = 0
        /// True once an operator, a function or a constant was used.
        var didWork = false

        init(_ chars: [Character]) { self.chars = chars }

        var atEnd: Bool {
            var probe = index
            while probe < chars.count, chars[probe] == " " { probe += 1 }
            return probe == chars.count
        }

        mutating func skipSpaces() {
            while index < chars.count, chars[index] == " " { index += 1 }
        }

        mutating func peek() -> Character? {
            skipSpaces()
            return index < chars.count ? chars[index] : nil
        }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let op = peek(), op == "+" || op == "-" || op == "−" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
                didWork = true
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }
            while let op = peek(), "*×x/÷".contains(op) {
                // "x" is a multiplication only between numbers ("3 x 4"), never a letter of a word.
                if op == "x", index + 1 < chars.count, chars[index + 1].isLetter { break }
                index += 1
                guard let rhs = parseFactor() else { return nil }
                value = (op == "/" || op == "÷") ? value / rhs : value * rhs
                didWork = true
            }
            return value
        }

        mutating func parseFactor() -> Double? {
            guard let base = parseUnary() else { return nil }
            if peek() == "^" {
                index += 1
                guard let exponent = parseFactor() else { return nil }
                didWork = true
                return pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() -> Double? {
            if let op = peek(), op == "-" || op == "−" || op == "+" {
                index += 1
                guard let value = parseUnary() else { return nil }
                return op == "+" ? value : -value
            }
            return parsePostfix()
        }

        mutating func parsePostfix() -> Double? {
            guard var value = parsePrimary() else { return nil }
            while let op = peek(), op == "%" || op == "!" {
                index += 1
                didWork = true
                if op == "%" {
                    value /= 100
                } else {
                    guard value >= 0, value <= 170, value == value.rounded() else { return nil }
                    value = (1...max(1, Int(value))).reduce(1.0) { $0 * Double($1) }
                }
            }
            return value
        }

        mutating func parsePrimary() -> Double? {
            guard let char = peek() else { return nil }
            if char == "(" {
                index += 1
                guard let value = parseExpression(), peek() == ")" else { return nil }
                index += 1
                return value
            }
            if char.isNumber || char == "." {
                let start = index
                while index < chars.count, chars[index].isNumber || chars[index] == "." || chars[index] == "_" { index += 1 }
                let text = String(chars[start..<index]).replacingOccurrences(of: "_", with: "")
                return Double(text)
            }
            if char == "π" { index += 1; didWork = true; return .pi }
            if char.isLetter {
                let start = index
                while index < chars.count, chars[index].isLetter || chars[index].isNumber { index += 1 }
                let name = String(chars[start..<index])
                switch name {
                case "pi": didWork = true; return .pi
                case "e": didWork = true; return M_E
                default: break
                }
                guard peek() == "(" else { return nil }
                index += 1
                guard let argument = parseExpression(), peek() == ")" else { return nil }
                index += 1
                didWork = true
                switch name {
                case "sqrt", "raiz", "raíz": return argument >= 0 ? argument.squareRoot() : nil
                case "cbrt": return cbrt(argument)
                case "abs": return abs(argument)
                case "round", "redondear": return argument.rounded()
                case "floor": return argument.rounded(.down)
                case "ceil": return argument.rounded(.up)
                case "ln": return argument > 0 ? Foundation.log(argument) : nil
                case "log": return argument > 0 ? log10(argument) : nil
                case "sin", "sen": return sin(argument)
                case "cos": return cos(argument)
                case "tan": return tan(argument)
                default: return nil
                }
            }
            return nil
        }
    }
}
