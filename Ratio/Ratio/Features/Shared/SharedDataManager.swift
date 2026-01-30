import Foundation

struct LiteGroup: Codable, Identifiable {
    let id: String
    let name: String
}

class SharedDataManager {
    static let shared = SharedDataManager()
    
    // WARNING: This ID must match the one configured in Xcode Capabilities > App Groups
    private let appGroupId = "group.com.redpixel.Ratio"
    private let groupsFilename = "groups_lite.json"
    private let receiptsQueueKey = "receipts_queue"
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    func saveGroupsToSharedContainer(groups: [SharedGroup]) {
        guard let url = containerURL?.appendingPathComponent(groupsFilename) else {
            print("❌ Shared Container not found. Check App Group ID.")
            return
        }
        
        let liteGroups = groups.map { LiteGroup(id: $0.id, name: $0.name) }
        
        do {
            let data = try JSONEncoder().encode(liteGroups)
            try data.write(to: url)
            print("✅ Groups synced to Shared Container: \(liteGroups.count) groups")
        } catch {
            print("❌ Failed to save groups to shared container: \(error)")
        }
    }
    
    func saveCurrentUserId(_ userId: String) {
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.set(userId, forKey: "current_user_id")
        }
    }
}

