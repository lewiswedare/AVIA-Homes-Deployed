import Foundation

extension URL {
    /// Rewrites the host of a Supabase storage URL to match the host configured in
    /// `EXPO_PUBLIC_SUPABASE_URL`. This lets you switch between the default
    /// `*.supabase.co` domain and a custom domain without re-uploading files.
    var rewrittenWithConfiguredSupabaseHost: URL {
        let configured = Config.EXPO_PUBLIC_SUPABASE_URL
        guard !configured.isEmpty,
              let configuredURL = URL(string: configured),
              let configuredHost = configuredURL.host,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else { return self }

        components.scheme = configuredURL.scheme ?? components.scheme
        components.host = configuredHost
        if let port = configuredURL.port {
            components.port = port
        }
        return components.url ?? self
    }
}

extension String {
    /// Convenience: parse this string as a URL and rewrite its host to the configured Supabase host.
    var urlWithConfiguredSupabaseHost: URL? {
        URL(string: self)?.rewrittenWithConfiguredSupabaseHost
    }
}
