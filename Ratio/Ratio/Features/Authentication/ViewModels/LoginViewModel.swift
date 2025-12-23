import Foundation
import SwiftUI
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // AuthService is an actor/thread-safe, so we can call it from here
    private let authService: AuthServiceProtocol
    
    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.login(email: email, password: password)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Erro ao efetuar login" // Localization needed
            }
        }
    }
}
