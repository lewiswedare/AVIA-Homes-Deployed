import SwiftUI
import UIKit

/// Centralised image cache + tuned URLCache.
///
/// Two layers:
/// 1. `URLCache.shared` is bumped from the iOS defaults (~20 MB mem / 150 MB
///    disk) to 200 MB / 1 GB. Every existing `AsyncImage` call site gets a
///    much higher cache hit rate immediately — no code changes needed.
/// 2. An in-memory `NSCache<NSURL, UIImage>` keyed by URL lets
///    `CachedAsyncImage` resolve a previously-loaded image *synchronously* on
///    the first frame, which removes the placeholder flash when re-entering a
///    screen.
enum ImageCache {
    static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 400
        cache.totalCostLimit = 200 * 1024 * 1024 // ~200 MB
        return cache
    }()

    static func configure() {
        // 200 MB RAM, 1 GB disk — generous, but capped so we never balloon.
        let mem = 200 * 1024 * 1024
        let disk = 1024 * 1024 * 1024
        let cache = URLCache(
            memoryCapacity: mem,
            diskCapacity: disk,
            directory: nil
        )
        URLCache.shared = cache
    }

    static func image(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    static func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        memory.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

/// Drop-in faster replacement for `AsyncImage(url:)` with:
/// - synchronous in-memory cache hit (no placeholder flash on revisit)
/// - shimmer placeholder while downloading
/// - graceful fallback view on error
///
/// Usage:
///
/// ```swift
/// CachedAsyncImage(url: url) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color(.secondarySystemBackground).shimmer()
/// }
/// ```
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let transaction: Transaction
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    init(
        url: URL?,
        transaction: Transaction = Transaction(animation: .easeOut(duration: 0.18)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
        // Synchronous memory-cache resolve avoids the first-frame blank flash.
        if let url, let cached = ImageCache.image(for: url) {
            _loadedImage = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.image(for: url) {
            withTransaction(transaction) { loadedImage = cached }
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else { return }
            ImageCache.store(image, for: url)
            await MainActor.run {
                withTransaction(transaction) { loadedImage = image }
            }
        } catch {
            // Silent fail — placeholder stays visible.
        }
    }
}

// Shimmer placeholder is provided by `View.shimmer(active:)` in
// `Microinteractions.swift`. Use it on a sized `Color` to fill image space
// while loading.
