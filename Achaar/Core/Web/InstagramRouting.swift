import Foundation

enum InstagramTab: String, CaseIterable, Identifiable {
    case home, explore, reels, messages, profile
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "house"
        case .explore: "magnifyingglass"
        case .reels: "play.rectangle"
        case .messages: "bubble.left.and.bubble.right"
        case .profile: "person.crop.circle"
        }
    }
    var path: String? {
        switch self {
        case .home: "/"
        case .explore: "/explore/"
        case .reels: "/reels/"
        case .messages: "/direct/inbox/"
        case .profile: nil
        }
    }
}

enum WebAction: String { case profile, create, activity }

enum InstagramRouting {
    static let home = URL(string: "https://www.instagram.com/")!

    static func isInstagram(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host?.lowercased() else { return false }
        return host == "instagram.com" || host.hasSuffix(".instagram.com")
    }

    static func allowsBridge(host: String, scheme: String, port: Int, mainFrame: Bool) -> Bool {
        mainFrame && scheme == "https" && (port == 0 || port == 443)
            && ["instagram.com", "www.instagram.com"].contains(host.lowercased())
    }

    static func tab(for path: String) -> InstagramTab? {
        if path == "/" { return .home }
        if path.hasPrefix("/explore/") { return .explore }
        if path.hasPrefix("/reels/") { return .reels }
        if path.hasPrefix("/direct/") { return .messages }
        return nil
    }

    static func shareURL(_ url: URL?) -> URL? {
        guard isInstagram(url), let url,
              !["accounts", "challenge", "checkpoint", "oauth", "direct"].contains(
                url.path.split(separator: "/").first.map(String.init) ?? "") else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }

    static func externalURL(_ url: URL) -> URL? {
        guard ["https", "http", "mailto", "tel"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil else { return nil }
        if ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
           url.host?.isEmpty != false { return nil }
        // Instagram's link shim is an outbound link, not a page to embed.
        if url.host?.lowercased() == "l.instagram.com",
           let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "u" })?.value,
           let destination = URL(string: target), destination.host?.lowercased() != "l.instagram.com" {
            return externalURL(destination)
        }
        return url
    }
}
