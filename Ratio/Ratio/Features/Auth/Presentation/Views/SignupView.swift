//
//  SignupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import PhotosUI
import SwiftUI
import UIKit
import AuthenticationServices

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showErrorAlert = false
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var pixKey = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isPasswordVisible = false
    @State private var appleNonce = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Configure seu perfil e comece.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        ZStack {
                            if let profileImageData,
                               let uiImage = UIImage(data: profileImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.separator).opacity(0.6), lineWidth: 1))

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Adicionar foto (opcional)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Nome", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .modifier(InputFieldStyle())

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .submitLabel(.next)
                        .modifier(InputFieldStyle())

                    TextField("Telefone (WhatsApp)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .submitLabel(.next)
                        .modifier(InputFieldStyle())

                    TextField("Chave Pix (opcional)", text: $pixKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .modifier(InputFieldStyle())

                    HStack(spacing: 8) {
                        if isPasswordVisible {
                            TextField("Senha", text: $password)
                                .textContentType(.newPassword)
                                .submitLabel(.go)
                        } else {
                            SecureField("Senha", text: $password)
                                .textContentType(.newPassword)
                                .submitLabel(.go)
                        }
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .modifier(InputFieldStyle())

                    Button(action: submit) {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Criar conta")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSubmitDisabled)

                VStack(spacing: 16) {
                    Text("Ou continue com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        googleButton
                        appleButton
                    }
                }
            }
                .frame(maxWidth: 420)

                if let message = authViewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Criar conta")
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Não foi possível criar a conta", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else {
                profileImageData = nil
                return
            }

            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        profileImageData = data
                    }
                }
            }
        }
    }

    private struct InputFieldStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
        }
    }

    private func submit() {
        authViewModel.signUp(
            email: email,
            password: password,
            displayName: displayName,
            phoneNumber: phoneNumber,
            pixKey: pixKey,
            photoData: profileImageData
        )
    }

    private var isSubmitDisabled: Bool {
        if authViewModel.isLoading || !email.isValidEmail || password.isEmpty {
            return true
        }

        return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var googleButton: some View {
        Button {
            guard let controller = UIApplication.topViewController() else {
                authViewModel.errorMessage = "Não foi possível iniciar o login."
                return
            }
            authViewModel.signInWithGoogle(presenting: controller)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .frame(width: 56, height: 44)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(authViewModel.isLoading)
    }

    private var appleButton: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { request in
                let nonce = SignInNonce.random()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = SignInNonce.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    authViewModel.signInWithApple(authorization: auth, rawNonce: appleNonce)
                case .failure(let error):
                    authViewModel.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(authViewModel.isLoading)
    }
}

#Preview {
    NavigationStack {
        SignupView()
    }
    .environmentObject(AuthViewModel())
    .environmentObject(AppRouter())
}
