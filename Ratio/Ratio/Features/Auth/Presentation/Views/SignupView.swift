//
//  SignupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import PhotosUI
import SwiftUI
import UIKit

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Criar conta")
                    .font(.largeTitle.bold())
                Text("Configure seu perfil e comece.")
                    .font(.subheadline)
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
                    .background(Color.white.opacity(0.95))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))

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

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.next)

                SecureField("Senha", text: $password)
                    .textContentType(.newPassword)
                    .submitLabel(.go)

                Button(action: submit) {
                    if authViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Criar conta")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitDisabled)
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)

            if let message = authViewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Criar conta")
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

    private func submit() {
        authViewModel.signUp(email: email, password: password, displayName: displayName)
    }

    private var isSubmitDisabled: Bool {
        if authViewModel.isLoading || email.isEmpty || password.isEmpty {
            return true
        }

        return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    NavigationStack {
        SignupView()
    }
    .environmentObject(AuthViewModel())
}
