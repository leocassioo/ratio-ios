import Foundation
import FirebaseAuth

protocol AuthServiceProtocol {
    func login(email: String, password: String) async throws
    func register(email: String, password: String) async throws
    func logout() throws
    var currentUser: User? { get }
}

class AuthService: AuthServiceProtocol {
    static let shared = AuthService()
    
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    func login(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func register(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    func logout() throws {
        try Auth.auth().signOut()
    }
}
