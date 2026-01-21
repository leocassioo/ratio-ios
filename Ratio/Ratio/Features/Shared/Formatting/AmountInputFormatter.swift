//
//  AmountInputFormatter.swift
//  Ratio
//
//  Created by Codex on 17/01/26.
//

import Foundation

struct AmountInputFormatter {
    static func sanitize(_ text: String) -> String {
        let digits = text.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        let value = (Double(digits) ?? 0) / 100
        return format(value)
    }

    static func parse(_ text: String) -> Double? {
        let digits = text.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return (Double(digits) ?? 0) / 100
    }

    static func format(_ value: Double, locale: Locale = Locale(identifier: "pt_BR")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }
}
