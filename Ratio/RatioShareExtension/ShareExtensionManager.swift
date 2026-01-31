import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct LiteGroup: Codable, Identifiable {
    let id: String
    let name: String
}

class ShareExtensionManager {
    static let shared = ShareExtensionManager()
    
    // WARNING: must match app group id
    private let appGroupId = "group.com.redpixel.Ratio"
    private let groupsFilename = "groups_lite.json"
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    init() {
        configureFirebase()
    }
    
    private func configureFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    func loadGroups() -> [LiteGroup] {
        guard let url = containerURL?.appendingPathComponent(groupsFilename) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let groups = try JSONDecoder().decode([LiteGroup].self, from: data)
            return groups
        } catch {
            print("Error loading groups: \(error)")
            return []
        }
    }
    
    func getCurrentUserId() -> String? {
        // Try to get from Auth first (Keychain Shared)
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        // Fallback to UserDefaults
        return UserDefaults(suiteName: appGroupId)?.string(forKey: "current_user_id")
    }
    
    func uploadReceipt(image: UIImage, groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = getCurrentUserId() else {
            completion(.failure(NSError(domain: "ShareExtension", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuário não logado"])))
            return
        }
        
        // 1. Resize Image (Max 1024px side - same as Main App)
        let resizedImage = resizeImage(image, maxDimension: 1024)
        
        // 2. Compress (Target < 100KB - same as Main App)
        guard let imageData = compressImageData(resizedImage, maxBytes: 100_000) else {
            completion(.failure(NSError(domain: "ShareExtension", code: 400, userInfo: [NSLocalizedDescriptionKey: "Erro ao processar imagem"])))
            return
        }
        
        let receiptId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("groups/\(groupId)/receipts/\(userId)/\(receiptId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    completion(.failure(error ?? NSError(domain: "ShareExtension", code: 500)))
                    return
                }
                self?.updateFirestore(groupId: groupId, userId: userId, url: downloadURL.absoluteString) { result in
                    switch result {
                    case .success(let removedURLs):
                        if !removedURLs.isEmpty {
                            self?.deleteReceipts(urls: removedURLs)
                        }
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        
        guard maxSide > maxDimension else { return image }
        
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func compressImageData(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.45
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.3 {
            quality -= 0.08
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }
    
    private func updateFirestore(
        groupId: String,
        userId: String,
        url: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupId)
        let memberRef = groupRef.collection("members").document(userId)
        
        let now = Date()
        db.runTransaction({ [self] (transaction, errorPointer) -> Any? in
            let groupDocument: DocumentSnapshot
            let memberDocument: DocumentSnapshot
            do {
                try groupDocument = transaction.getDocument(groupRef)
                try memberDocument = transaction.getDocument(memberRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = groupDocument.data() else { return nil }
            
            // 1. Update membersPreview array
            var membersPreview = (data["membersPreview"] as? [[String: Any]]) 
                ?? (data["members"] as? [[String: Any]] ?? [])
            
            var didUpdate = false
            let historyUpdate = self.updatedReceiptHistory(from: memberDocument, url: url, now: now)
            for (index, member) in membersPreview.enumerated() {
                if let id = member["userId"] as? String, id == userId {
                    var updatedMember = member
                    updatedMember["receiptURL"] = url
                    updatedMember["status"] = "submitted"
                    updatedMember["submittedAt"] = Timestamp(date: now)
                    updatedMember["updatedAt"] = Timestamp(date: now)
                    if !historyUpdate.history.isEmpty {
                        updatedMember["receiptHistory"] = historyUpdate.history
                    }
                    membersPreview[index] = updatedMember
                    didUpdate = true
                    break
                }
            }
            
            if didUpdate {
                transaction.updateData(["membersPreview": membersPreview], forDocument: groupRef)
            }
            
            // 2. Update Subcollection Member Document
            transaction.updateData([
                "receiptURL": url,
                "status": "submitted",
                "submittedAt": FieldValue.serverTimestamp(),
                "receiptHistory": historyUpdate.history,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: memberRef)
            
            return historyUpdate.removedURLs
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(object as? [String] ?? []))
            }
        }
    }

    private func updatedReceiptHistory(from snapshot: DocumentSnapshot, url: String, now: Date) -> (history: [[String: Any]], removedURLs: [String]) {
        let existing = snapshot.data()?["receiptHistory"] as? [[String: Any]] ?? []
        let entry: [String: Any] = [
            "id": UUID().uuidString,
            "url": url,
            "submittedAt": Timestamp(date: now)
        ]
        let combined = [entry] + existing
        let trimmed = Array(combined.prefix(6))
        let removedURLs = combined.dropFirst(6).compactMap { $0["url"] as? String }
        return (trimmed, removedURLs)
    }

    private func deleteReceipts(urls: [String]) {
        for url in urls {
            let ref = Storage.storage().reference(forURL: url)
            ref.delete { _ in }
        }
    }
}
