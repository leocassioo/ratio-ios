//
//  CachedAsyncImage.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import SwiftUI
import Combine

enum CachedImagePhase: Equatable {
    case empty
    case success(Image)
    case failure
}

final class CachedImageLoader: ObservableObject {
    @Published private(set) var phase: CachedImagePhase = .empty
    private static let cache = URLCache(
        memoryCapacity: 8 * 1024 * 1024,
        diskCapacity: 64 * 1024 * 1024,
        diskPath: "ratio-images"
    )
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    private var task: URLSessionDataTask?

    func load(url: URL?) {
        task?.cancel()
        guard let url else {
            phase = .empty
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        if let cached = Self.cache.cachedResponse(for: request),
           let image = UIImage(data: cached.data) {
            phase = .success(Image(uiImage: image))
            return
        }

        phase = .empty
        task = Self.session.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                if let data, let image = UIImage(data: data) {
                    if let response {
                        let cachedResponse = CachedURLResponse(response: response, data: data)
                        Self.cache.storeCachedResponse(cachedResponse, for: request)
                    }
                    self.phase = .success(Image(uiImage: image))
                } else {
                    self.phase = .failure
                }
            }
        }
        task?.resume()
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content
    @StateObject private var loader = CachedImageLoader()

    var body: some View {
        content(loader.phase)
            .onAppear {
                loader.load(url: url)
            }
            .onChange(of: url) { _, newValue in
                loader.load(url: newValue)
            }
    }
}
