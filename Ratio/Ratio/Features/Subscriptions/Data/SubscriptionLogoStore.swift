//
//  SubscriptionLogoStore.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import Foundation
import UIKit

final class SubscriptionLogoStore {
    static let shared = SubscriptionLogoStore()
    static let logoUpdatedNotification = Notification.Name("subscriptionLogoUpdated")

    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, UIImage>()
    private let directoryName = "SubscriptionLogos"

    private init() {}

    func loadLogo(for subscriptionId: String) -> UIImage? {
        if let cached = cache.object(forKey: subscriptionId as NSString) {
            return cached
        }
        guard let url = logoURL(for: subscriptionId),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: subscriptionId as NSString)
        return image
    }

    func saveLogo(image: UIImage, for subscriptionId: String) {
        guard let url = logoURL(for: subscriptionId) else { return }
        let resized = image.resized(maxDimension: 96)
        guard let data = resized.jpegData(compressionQuality: 0.5) else { return }
        do {
            try ensureDirectoryExists()
            try data.write(to: url, options: [.atomic])
            cache.setObject(resized, forKey: subscriptionId as NSString)
            NotificationCenter.default.post(
                name: SubscriptionLogoStore.logoUpdatedNotification,
                object: nil,
                userInfo: ["id": subscriptionId]
            )
        } catch {
            #if DEBUG
            print("Failed to save subscription logo:", error)
            #endif
        }
    }

    func removeLogo(for subscriptionId: String) {
        guard let url = logoURL(for: subscriptionId) else { return }
        try? fileManager.removeItem(at: url)
        cache.removeObject(forKey: subscriptionId as NSString)
        NotificationCenter.default.post(
            name: SubscriptionLogoStore.logoUpdatedNotification,
            object: nil,
            userInfo: ["id": subscriptionId]
        )
    }

    private func logoURL(for subscriptionId: String) -> URL? {
        guard let directory = logosDirectoryURL() else { return nil }
        return directory.appendingPathComponent("\(subscriptionId).jpg")
    }

    private func ensureDirectoryExists() throws {
        guard let directory = logosDirectoryURL() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func logosDirectoryURL() -> URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = Swift.max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
