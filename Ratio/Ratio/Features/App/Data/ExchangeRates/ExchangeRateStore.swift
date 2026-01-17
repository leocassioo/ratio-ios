//
//  ExchangeRateStore.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import FirebaseFirestore
import Foundation

final class ExchangeRateStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func listenUsdRate(onChange: @escaping (Result<ExchangeRate?, Error>) -> Void) -> ListenerRegistration {
        db.collection("exchangeRates")
            .document("usd")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                guard let data = snapshot?.data() else {
                    onChange(.success(nil))
                    return
                }
                let rate = data["rate"] as? Double ?? 0
                let marginPct = data["marginPct"] as? Double ?? 0
                let source = data["source"] as? String ?? "BCB_PTAX"
                let asOf = (data["asOf"] as? Timestamp)?.dateValue() ?? Date()
                let exchangeRate = ExchangeRate(
                    rate: rate,
                    marginPct: marginPct,
                    asOf: asOf,
                    source: source
                )
                onChange(.success(exchangeRate))
            }
    }
}
