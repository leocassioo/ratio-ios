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
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: EditProfileViewModel
    private let analytics = AnalyticsService.shared

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
                    .foregroundStyle(.secondary)
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
                HStack(spacing: 4) {
                    Text("Para alterar o email,")
                    Button("toque aqui.") {
                        router.push(.changeEmail, in: .settings)
                    }
                    .buttonStyle(.plain)
                    .underline()
                }
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

            Section {
                Button {
                    router.push(.deleteAccount, in: .settings)
                } label: {
                    HStack {
                        Text("Excluir conta")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Essa ação remove permanentemente sua conta e seus dados.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.screenView(.screen_profile)
            viewModel.loadProfile()
            viewModel.saveSuccess = false
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
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
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
