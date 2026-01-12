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
        pixKey: String?,
        phoneNumber: String? = nil
    ) -> URL? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(amount)"
        
        var message = "Oi \(memberName)! O pagamento do grupo *\(groupName)* (\(formattedAmount)) está pendente."
        
        if let pixKey = pixKey, !pixKey.isEmpty {
            message += "\n\nSegue minha chave Pix para pagamento:\n\(pixKey)"
        }
        
        message += "\n\nPor favor, envie o comprovante pelo app Ratio assim que possível! 🚀"
        message += "\n\nBaixe o Ratio aqui: https://apps.apple.com/br/app/ratio/id6475656565"
        
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
