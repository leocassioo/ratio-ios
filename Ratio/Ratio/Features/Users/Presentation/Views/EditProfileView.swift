//
//  EditProfileView.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import FirebaseAuth
import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel

    init(user: User) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    avatarView

                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Text("Alterar foto")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                TextField("Nome", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .textContentType(.name)

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(true)

                TextField("Telefone", text: $viewModel.phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                TextField("Chave Pix para recebimento", text: $viewModel.pixKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Dados pessoais")
            } footer: {
                Text("Para alterar o email, utilize o suporte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    viewModel.saveChanges()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Salvar alterações")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if viewModel.saveSuccess {
                Section {
                    Text("Perfil atualizado com sucesso.")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Perfil")
        .onAppear {
            viewModel.loadProfile()
        }
        .onChange(of: viewModel.selectedPhoto) { _, _ in
            viewModel.handleSelectedPhotoChange()
        }
    }

    private var avatarView: some View {
        ZStack {
            if let data = viewModel.profileImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = viewModel.remotePhotoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .background(Color(.secondarySystemBackground))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
    }
}
