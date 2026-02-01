//
//  WhatsNewView.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import SwiftUI

struct WhatsNewState {
    let payload: WhatsNewPayload
    let slides: [WhatsNewPayload.WhatsNewSlide]
    let isOutdated: Bool
    let source: WhatsNewSource

    var appStoreURL: URL? { payload.appStoreURL }
}

enum WhatsNewSource {
    case auto
    case settings
}

struct WhatsNewView: View {
    let state: WhatsNewState
    let onContinue: () -> Void
    let onUpdate: (URL?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var didFinalize = false
    @State private var expandedImageURL: String?
    private let analytics = AnalyticsService.shared

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 16) {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(state.slides.enumerated()), id: \.element.id) { index, slide in
                            WhatsNewSlideView(
                                slide: slide,
                                imageHeight: proxy.size.height * 0.55,
                                onImageTap: { expandedImageURL = $0 }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    if state.slides.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<state.slides.count, id: \.self) { index in
                                Circle()
                                    .frame(width: 8, height: 8)
                                    .foregroundColor(index == currentIndex ? .accentColor : .gray.opacity(0.3))
                            }
                        }
                        .padding(.bottom, 4)
                        .animation(.easeInOut, value: currentIndex)
                    }

                    Group {
                        if state.isOutdated, state.appStoreURL != nil {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                Button {
                                    finalize {
                                        analytics.track(.whatsnew_update_tap)
                                        onUpdate(state.appStoreURL)
                                    }
                                } label: {
                                    Text("Atualizar agora")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)

                                Button {
                                    finalize {
                                        analytics.track(.whatsnew_continue)
                                        onContinue()
                                    }
                                } label: {
                                    Text("Continuar")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        } else {
                            Button {
                                finalize {
                                    analytics.track(.whatsnew_continue)
                                    onContinue()
                                }
                            } label: {
                                Text("Continuar")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Novidades")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finalize {
                            onContinue()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onDisappear {
            finalize { onContinue() }
        }
        .onAppear {
            analytics.screenView(.screen_whats_new)
            analytics.track(.whatsnew_view)
            if state.source == .settings {
                analytics.track(.settings_whats_new_open)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { expandedImageURL != nil },
                set: { if !$0 { expandedImageURL = nil } }
            )
        ) {
            if let url = expandedImageURL {
                NavigationStack {
                    WhatsNewImageViewer(urlString: url)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    expandedImageURL = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
        }
    }

    private func finalize(_ action: () -> Void) {
        guard !didFinalize else { return }
        didFinalize = true
        action()
        dismiss()
    }
}

private struct WhatsNewSlideView: View {
    let slide: WhatsNewPayload.WhatsNewSlide
    let imageHeight: CGFloat
    let onImageTap: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            RemoteImageView(urlString: slide.imageUrl, contentMode: .fit)
                .frame(height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    onImageTap(slide.imageUrl)
                }

            Text(slide.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(slide.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .lineLimit(3)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }
}

private struct RemoteImageView: View {
    let urlString: String
    let contentMode: ContentMode
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                if contentMode == .fill {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .clipped()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            image = nil
            await loadImage()
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            ProgressView()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return }

        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let cachedImage = UIImage(data: cached.data) {
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            if let loaded = UIImage(data: data) {
                image = loaded
                let cached = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cached, for: request)
            }
        } catch {
            return
        }
    }
}

private struct WhatsNewImageViewer: View {
    let urlString: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            RemoteImageView(urlString: urlString, contentMode: .fit)
                .padding()
        }
    }
}

#Preview {
    let payload = WhatsNewPayload(
        version: "1.0.0",
        minVersion: nil,
        appStoreUrl: nil,
        slides: [
            "pt-BR": [
                .init(title: "Novidades do Ratio", description: "Veja as principais melhorias desta versao.", imageUrl: ""),
                .init(title: "Grupos e assinaturas", description: "Tudo em um so lugar.", imageUrl: "")
            ]
        ]
    )
    let state = WhatsNewState(payload: payload, slides: payload.slides(for: Locale(identifier: "pt-BR")), isOutdated: false, source: .auto)
    return WhatsNewView(state: state, onContinue: {}, onUpdate: { _ in })
}
