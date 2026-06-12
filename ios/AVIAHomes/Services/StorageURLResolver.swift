import SwiftUI
import Supabase

/// Converts stored public-style Supabase storage URLs into short-lived signed
/// URLs at display time.
///
/// The `documents` and `contracts` buckets are private: database rows keep the
/// public-style URL (it encodes bucket + path), and any view that opens or
/// downloads a file resolves it through this helper first. URLs that do not
/// point at a private bucket (e.g. `catalog-images` or external links) pass
/// through unchanged.
enum StorageURLResolver {
    /// Buckets that require signed access.
    private static let privateBuckets: Set<String> = ["documents", "contracts"]

    /// Signed URLs are valid for 1 hour; cache entries expire slightly earlier.
    private static let signedURLLifetime = 3600
    private static var cache: [String: (url: URL, expires: Date)] = [:]

    /// Extracts (bucket, objectPath) from a Supabase storage object URL.
    static func storageObject(from url: URL) -> (bucket: String, path: String)? {
        let markers = ["/storage/v1/object/public/", "/storage/v1/object/sign/"]
        // `url.path` is already percent-decoded.
        let fullPath = url.path
        for marker in markers {
            guard let range = fullPath.range(of: marker) else { continue }
            let rest = fullPath[range.upperBound...]
            guard let slash = rest.firstIndex(of: "/") else { continue }
            let bucket = String(rest[..<slash])
            let objectPath = String(rest[rest.index(after: slash)...])
            guard !bucket.isEmpty, !objectPath.isEmpty else { continue }
            return (bucket, objectPath)
        }
        return nil
    }

    /// Resolves a stored URL string to an openable URL. Returns a signed URL
    /// for private-bucket objects, the original URL otherwise, and falls back
    /// to the original on signing failure so links never dead-end.
    static func resolve(_ urlString: String?) async -> URL? {
        guard let urlString, !urlString.isEmpty, let original = URL(string: urlString) else { return nil }
        guard let object = storageObject(from: original), privateBuckets.contains(object.bucket) else {
            return original
        }
        if let cached = cache[urlString], cached.expires > Date.now {
            return cached.url
        }
        do {
            let signed = try await SupabaseService.shared.client.storage
                .from(object.bucket)
                .createSignedURL(path: object.path, expiresIn: signedURLLifetime)
            cache[urlString] = (signed, Date.now.addingTimeInterval(TimeInterval(signedURLLifetime - 300)))
            return signed
        } catch {
            print("[StorageURLResolver] Failed to sign \(object.bucket)/\(object.path): \(error)")
            return original
        }
    }
}

/// Drop-in replacement for `Link(destination:)` for stored storage URLs.
/// Resolves the signed URL on tap, then opens it.
struct StorageFileLink<Label: View>: View {
    let urlString: String?
    @ViewBuilder let label: () -> Label

    @Environment(\.openURL) private var openURL
    @State private var isResolving = false

    var body: some View {
        Button {
            guard !isResolving else { return }
            isResolving = true
            Task {
                if let url = await StorageURLResolver.resolve(urlString) {
                    openURL(url)
                }
                isResolving = false
            }
        } label: {
            label()
        }
        .disabled(urlString == nil || urlString?.isEmpty == true)
    }
}

/// Resolves a stored storage URL and hands the signed URL to its content
/// builder (for views that need a concrete `URL`, e.g. PDF thumbnails).
struct ResolvedStorageURL<Content: View>: View {
    let urlString: String?
    @ViewBuilder let content: (URL) -> Content

    @State private var resolved: URL?

    var body: some View {
        Group {
            if let resolved {
                content(resolved)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .task(id: urlString) {
            resolved = await StorageURLResolver.resolve(urlString)
        }
    }
}
