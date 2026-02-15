//
//  WhatsAppMessageBuilder.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

struct WhatsAppMessageBuilder {
    static func buildPaymentRequest(
        memberName: String,
        groupName: String,
        amount: Double,
        currencyCode: String,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        pixKey: String?,
        phoneNumber: String? = nil
    ) -> URL? {
        func formatted(_ value: Double, code: String) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            formatter.locale = Locale(identifier: "pt_BR")
            return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
        }

        let formattedAmount = formatted(amount, code: currencyCode)
        var messageAmount = formattedAmount
        if let originalAmount, let originalCurrencyCode,
           originalCurrencyCode != currencyCode || originalAmount != amount {
            let formattedOriginal = formatted(originalAmount, code: originalCurrencyCode)
            messageAmount = "\(formattedAmount) (\(formattedOriginal))"
        }

        var message = "Oi \(memberName)! O pagamento do grupo *\(groupName)* \(messageAmount) está pendente."
        
        if let pixKey = pixKey, !pixKey.isEmpty {
            message += "\n\nSegue minha chave Pix para pagamento:\n\(pixKey)"
        }
        
        message += "\n\nPor favor, envie o comprovante pelo app Ratio assim que possível! 🚀"
        message += "\n\nBaixe o Ratio aqui: https://apps.apple.com/us/app/ratio-dividir-contas-e-gastos/id6757924426"
        
        let baseURL: String
        if let phoneNumber = phoneNumber?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), !phoneNumber.isEmpty {
             baseURL = "https://wa.me/\(phoneNumber)"
        } else {
             baseURL = "https://wa.me/"
        }
        
        let urlString = "\(baseURL)?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return URL(string: urlString)
    }
}
