import Foundation
import FirebaseFirestore

class SubscriptionService {
    static let shared = SubscriptionService()
    private let db = Firestore.firestore()
    
    private var collectionRef: CollectionReference {
        return db.collection("subscriptions")
    }
    
    func addSubscription(_ subscription: Subscription) throws {
        try collectionRef.addDocument(from: subscription)
    }
    
    func fetchSubscriptions(for userId: String) async throws -> [Subscription] {
        let snapshot = try await collectionRef
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Subscription.self)
        }
    }
    
    func deleteSubscription(id: String) async throws {
        try await collectionRef.document(id).delete()
    }
    
    // Future: Update, Fetch by Group, etc.
}
