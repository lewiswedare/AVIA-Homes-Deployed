import SwiftUI
import UIKit

/// Centralised image cache + tuned URLCache + background prefetcher.
///
/// Three layers:
/// 1. `URLCache.shared` is bumped from the iOS defaults (~20 MB mem / 150 MB
///    disk) to 200 MB / 1 GB. Every existing `AsyncImage` call site gets a
///    much higher cache hit rate immediately — no code changes needed.
/// 2. An in-memory `NSCache<NSURL, UIImage>` keyed by URL lets
///    `CachedAsyncImage` resolve a previously-loaded image *synchronously* on
///    the first frame, which removes the placeholder flash when re-entering a
///    screen.
/// 3. `ImagePrefetcher` warms both caches in the background as soon as data
///    is loaded so the *first* visit feels instant too.
enum ImageCache {
    static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 600
        cache.totalCostLimit = 250 * 1024 * 1024 // ~250 MB
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

/// Background image prefetcher. Once data lands (designs, packages, news,
/// facades, room assignments…), feed its image URLs into
/// `ImagePrefetcher.prefetch(_:)` so the bytes are already on disk + decoded
/// in memory by the time the user scrolls to them.
///
/// Safe to call repeatedly with overlapping URLs — in-flight downloads are
/// de-duplicated and already-cached URLs short-circuit immediately.
enum ImagePrefetcher {
    /// URLs we've started (or finished) prefetching this app launch. Keeps us
    /// from re-issuing the same request twice when many screens warm the
    /// same hero image.
    private static let inflight = NSCache<NSURL, NSNumber>()

    /// Dedicated session with a small concurrent op cap so prefetching never
    /// starves user-initiated requests on slow networks.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache.shared
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.httpMaximumConnectionsPerHost = 6
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    /// Prefetch a list of optional URL strings — empties and bad URLs are
    /// silently dropped.
    static func prefetch(urlStrings: [String?]) {
        let urls: [URL] = urlStrings.compactMap { s in
            guard let s, !s.isEmpty else { return nil }
            return URL(string: s)
        }
        prefetch(urls: urls)
    }

    static func prefetch(urls: [URL?]) {
        let real = urls.compactMap { $0 }
        prefetch(urls: real)
    }

    static func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in urls {
                await prefetchOne(url)
            }
        }
    }

    private static func prefetchOne(_ url: URL) async {
        // Skip if already in our memory cache or already inflight.
        if ImageCache.image(for: url) != nil { return }
        if inflight.object(forKey: url as NSURL) != nil { return }
        inflight.setObject(1 as NSNumber, forKey: url as NSURL)

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        // Fast path: URLCache already has bytes.
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data) {
            ImageCache.store(image, for: url)
            return
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let image = UIImage(data: data) else { return }
            ImageCache.store(image, for: url)
            // Persist into URLCache so AsyncImage call sites (which we don't
            // control) also serve from disk on subsequent loads.
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let cached = CachedURLResponse(
                    response: response,
                    data: data,
                    userInfo: nil,
                    storagePolicy: .allowed
                )
                URLCache.shared.storeCachedResponse(cached, for: request)
            }
        } catch {
            // Drop from inflight so a later call can retry.
            inflight.removeObject(forKey: url as NSURL)
        }
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
