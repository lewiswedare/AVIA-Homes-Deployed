import Foundation

extension URL {
    /// Appends Supabase Render API transform querystring params to a public storage URL.
    /// Callers opt in per display site; the underlying `getPublicURL` call is left untouched
    /// so that original URLs remain valid for full-resolution viewing.
    func supabaseImageTransform(width: Int? = nil, height: Int? = nil, quality: Int = 80, resize: String = "cover") -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var items = comps.queryItems ?? []
        if let w = width { items.append(.init(name: "width", value: String(w))) }
        if let h = height { items.append(.init(name: "height", value: String(h))) }
        items.append(.init(name: "quality", value: String(quality)))
        items.append(.init(name: "resize", value: resize))
        comps.queryItems = items
        return comps.url ?? self
    }
}
