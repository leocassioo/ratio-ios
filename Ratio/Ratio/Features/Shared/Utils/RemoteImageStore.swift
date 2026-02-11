//
//  RemoteImageStore.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import CryptoKit
import Foundation
import UIKit

final class RemoteImageStore {
    static let shared = RemoteImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let directoryName = "RemoteImageCache"

    private init() {}

    func loadImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        guard let fileURL = cacheURL(for: url),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    func fetchImage(for url: URL) async -> UIImage? {
        if let cached = loadImage(for: url) {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            saveToDisk(data: data, image: image, url: url)
            return image
        } catch {
            return nil
        }
    }

    private func saveToDisk(data: Data, image: UIImage, url: URL) {
        guard let fileURL = cacheURL(for: url) else { return }
        do {
            try ensureDirectoryExists()
            try data.write(to: fileURL, options: [.atomic])
            cache.setObject(image, forKey: cacheKey(for: url) as NSString)
        } catch {
            #if DEBUG
            print("Failed to cache remote image:", error)
            #endif
        }
    }

    private func cacheURL(for url: URL) -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        return directory.appendingPathComponent(cacheKey(for: url))
    }

    private func ensureDirectoryExists() throws {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
