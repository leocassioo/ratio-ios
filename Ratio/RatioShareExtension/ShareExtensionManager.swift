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
        
        let receiptId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("groups/\(groupId)/receipts/\(userId)/\(receiptId).jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ShareExtension", code: 400, userInfo: [NSLocalizedDescriptionKey: "Erro ao processar imagem"])))
            return
        }
        
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
                self?.updateFirestore(groupId: groupId, userId: userId, url: downloadURL.absoluteString, completion: completion)
            }
        }
    }
    
    private func updateFirestore(groupId: String, userId: String, url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let groupDocument: DocumentSnapshot
            do {
                try groupDocument = transaction.getDocument(groupRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = groupDocument.data() else { return nil }
            
            // 1. Update membersPreview array
            var membersPreview = (data["membersPreview"] as? [[String: Any]]) 
                ?? (data["members"] as? [[String: Any]] ?? [])
            
            var didUpdate = false
            for (index, member) in membersPreview.enumerated() {
                if let id = member["userId"] as? String, id == userId {
                    var updatedMember = member
                    updatedMember["receiptURL"] = url
                    updatedMember["status"] = "submitted"
                    updatedMember["updatedAt"] = Timestamp(date: Date())
                    membersPreview[index] = updatedMember
                    didUpdate = true
                    break
                }
            }
            
            if didUpdate {
                transaction.updateData(["membersPreview": membersPreview], forDocument: groupRef)
            }
            
            // 2. Update Subcollection Member Document
            let memberRef = groupRef.collection("members").document(userId)
            transaction.updateData([
                "receiptURL": url,
                "status": "submitted",
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: memberRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
