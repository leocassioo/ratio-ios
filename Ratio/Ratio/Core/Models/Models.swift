import Foundation
import FirebaseFirestore

enum BillingFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    
    var id: String { rawValue }
}

enum PaymentStatus: String, Codable {
    case paid
    case pending
    case late
}

struct GroupMember: Codable, Identifiable {
    let id: String
    let name: String
    let photoUrl: String?
    let amountToPay: Double
    var status: PaymentStatus
}

struct RatioGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String // e.g. "Family Netflix"
    var totalAmount: Double
    var frequency: BillingFrequency
    var members: [GroupMember]
    var category: String // "Streaming"
    
    // UI Helpers
    var paidCount: Int { members.filter { $0.status == .paid }.count }
    var progress: Double { Double(paidCount) / Double(members.count) }
}

// Keeping basic user for Auth
struct RatioUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let paymentMethods: [String]?
    
    init(id: String, name: String, email: String, paymentMethods: [String]? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.paymentMethods = paymentMethods
    }
}

// Legacy Subscription model (might merge into Group later, but keeping for solo subs)
struct Subscription: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var totalAmount: Double
    var billingDay: Int
    var frequency: BillingFrequency
    var ownerId: String
    var groupId: String?
    var category: String 
    var createdAt: Date?
}
