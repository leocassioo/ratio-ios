import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    @State private var selectedGroup: LiteGroup?
    @State private var groups: [LiteGroup] = []
    @State private var isSelectedGroupOwner = false
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Callbacks to communicate with ShareViewController
    var extensionContext: NSExtensionContext?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                        }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enviar para")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.leading, 4)
                    
                    Menu {
                        ForEach(groups) { group in
                            Button {
                                selectedGroup = group
                                updateOwnerFlag(for: group)
                            } label: {
                                if selectedGroup?.id == group.id {
                                    Label(group.name, systemImage: "checkmark")
                                } else {
                                    Text(group.name)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedGroup?.name ?? "Selecionar Grupo")
                                .font(.body.weight(.medium))
                                .foregroundStyle(selectedGroup == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    Text(isSelectedGroupOwner
                         ? "Você é o organizador deste grupo e não pode enviar comprovante."
                         : "O organizador será notificado assim que você enviar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: send) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Enviar Comprovante")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedGroup == nil || image == nil || isLoading || isSelectedGroupOwner)
            }
            .padding()
            .navigationTitle("Novo Comprovante")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: cancel)
                }
            }
            .alert("Erro", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear(perform: loadData)
    }
    
    private func loadData() {
        // Load Groups
        self.groups = ShareExtensionManager.shared.loadGroups()
        self.selectedGroup = groups.first
        if let group = selectedGroup {
            updateOwnerFlag(for: group)
        }
        
        // Load Image
        extractImage()
    }

    private func updateOwnerFlag(for group: LiteGroup) {
        let ownerId = ShareExtensionManager.shared.getOwnerId(for: group.id)
        let currentUserId = ShareExtensionManager.shared.getCurrentUserId()
        isSelectedGroupOwner = ownerId != nil && ownerId == currentUserId
    }
    
    private func extractImage() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (imageURL, error) in
                        DispatchQueue.main.async {
                            if let url = imageURL as? URL, let data = try? Data(contentsOf: url) {
                                self.image = UIImage(data: data)
                            } else if let image = imageURL as? UIImage {
                                self.image = image
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func send() {
        guard let image = image, let group = selectedGroup else { return }
        
        isLoading = true
        ShareExtensionManager.shared.uploadReceipt(image: image, groupId: group.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "UserCancelled", code: 0))
    }
}
