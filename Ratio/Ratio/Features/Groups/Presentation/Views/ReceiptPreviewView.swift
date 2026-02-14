//
//  ReceiptPreviewView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI
import Photos

struct ReceiptPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: ReceiptHistoryItem
    let groupId: String?
    let memberId: String?
    private var receiptURL: URL? { URL(string: receipt.url) }
    @State private var shareFileURL: URL?
    @State private var isPreparingShare = false
    @State private var shareErrorMessage: String?
    @State private var isShowingShare = false
    @State private var isSavingToPhotos = false
    @State private var saveMessage: String?
    @State private var isImageLoaded = false
    private let analytics = AnalyticsService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(formattedDate(receipt.submittedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let url = receiptURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                                .onAppear {
                                    isImageLoaded = true
                                }
                        case .failure:
                            Text("Não foi possível carregar o comprovante.")
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text("Link inválido.")
                        .foregroundStyle(.secondary)
                }

                if isImageLoaded {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        if isSavingToPhotos {
                            ProgressView()
                        } else {
                            Label("Salvar na galeria", systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingToPhotos || receiptURL == nil)
                }
            }
            .padding()
        }
        .navigationTitle("Comprovante")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await prepareShareFile()
                    }
                } label: {
                    if isPreparingShare {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isPreparingShare || receiptURL == nil)
            }
        }
        .sheet(isPresented: $isShowingShare) {
            if let shareFileURL {
                ShareSheet(items: [shareFileURL])
            }
        }
        .alert("Erro ao compartilhar", isPresented: Binding(get: { shareErrorMessage != nil }, set: { _ in shareErrorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .alert("Salvar na galeria", isPresented: Binding(get: { saveMessage != nil }, set: { _ in saveMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveMessage ?? "")
        }
        .onAppear {
            analytics.screenView(.screen_receipt_preview)
            var params: [String: Any] = [:]
            if let groupId { params["group_id"] = groupId }
            if let memberId { params["member_id"] = memberId }
            analytics.track(.receipt_view, parameters: params)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func prepareShareFile() async {
        guard let url = receiptURL else { return }
        await MainActor.run { isPreparingShare = true }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let filename = suggestedFilename(from: response, fallback: "comprovante.jpg")
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: fileURL, options: [.atomic])
            await MainActor.run {
                shareFileURL = fileURL
                isShowingShare = true
                isPreparingShare = false
            }
            var params: [String: Any] = [:]
            if let groupId { params["group_id"] = groupId }
            if let memberId { params["member_id"] = memberId }
            analytics.track(.receipt_share, parameters: params)
        } catch {
            await MainActor.run {
                isPreparingShare = false
                shareErrorMessage = "Não foi possível preparar o arquivo para compartilhamento."
            }
        }
    }

    private func suggestedFilename(from response: URLResponse, fallback: String) -> String {
        if let http = response as? HTTPURLResponse,
           let contentDisposition = http.allHeaderFields["Content-Disposition"] as? String,
           let name = parseFilename(from: contentDisposition) {
            return name
        }
        return fallback
    }

    private func parseFilename(from contentDisposition: String) -> String? {
        let parts = contentDisposition.split(separator: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("filename=") {
                return trimmed.dropFirst("filename=".count).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }

    private func saveToPhotos() async {
        guard let url = receiptURL else { return }
        await MainActor.run { isSavingToPhotos = true }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                isSavingToPhotos = false
                saveMessage = "Permissão de fotos não concedida."
            }
            var params: [String: Any] = ["result": "denied"]
            if let groupId { params["group_id"] = groupId }
            if let memberId { params["member_id"] = memberId }
            analytics.track(.receipt_save_photos, parameters: params)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    isSavingToPhotos = false
                    saveMessage = "Não foi possível ler a imagem."
                }
                return
            }

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }

            await MainActor.run {
                isSavingToPhotos = false
                saveMessage = "Comprovante salvo na galeria."
            }
            var params: [String: Any] = ["result": "success"]
            if let groupId { params["group_id"] = groupId }
            if let memberId { params["member_id"] = memberId }
            analytics.track(.receipt_save_photos, parameters: params)
        } catch {
            await MainActor.run {
                isSavingToPhotos = false
                saveMessage = "Falha ao salvar na galeria."
            }
            var params: [String: Any] = ["result": "error"]
            if let groupId { params["group_id"] = groupId }
            if let memberId { params["member_id"] = memberId }
            analytics.track(.receipt_save_photos, parameters: params)
        }
    }
}


