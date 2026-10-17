import Foundation

enum InstagramTab: String, CaseIterable, Identifiable {
    case home, explore, reels, messages, profile
    var id: String { rawValue }
    static let displayOrder: [InstagramTab] = [.home, .reels, .messages, .explore, .profile]
    var title: String { self == .explore ? "Search" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "house"
        case .explore: "magnifyingglass"
        case .reels: "play.rectangle"
        case .messages: "paperplane"
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

enum WebAction: String, CaseIterable, Identifiable {
    case profile, create, activity, search, inbox, newMessage, requests, saved, archive, editProfile, accountSettings, like, save, comments, sharePost
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .like: "Like / unlike visible post"
        case .save: "Save / unsave visible post"
        case .comments: "Comments on visible post"
        case .sharePost: "Share visible post"
        case .profile: "Your profile"
        case .create: "Create"
        case .activity: "Activity"
        case .search: "Search"
        case .newMessage: "New message"
        case .requests: "Message requests"
        case .saved: "Saved"
        case .archive: "Archive"
        case .editProfile: "Edit profile"
        case .accountSettings: "Instagram settings"
        }
    }
    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .like: "heart"
        case .save: "bookmark"
        case .comments: "bubble"
        case .sharePost: "paperplane"
        case .profile: "person.crop.circle"
        case .create: "plus.app"
        case .activity: "heart"
        case .search: "magnifyingglass"
        case .newMessage: "square.and.pencil"
        case .requests: "tray"
        case .saved: "bookmark"
        case .archive: "clock.arrow.circlepath"
        case .editProfile: "person.crop.circle.badge.pencil"
        case .accountSettings: "gearshape"
        }
    }
}

enum InstagramRouting {
    static let home = URL(string: "https://www.instagram.com/")!

    // Instagram's embedded-browser variant opens a desktop post dialog whose
    // comment column is hidden on phones. Safari tokens select its mobile flow;
    // retain the actual WebKit platform/engine rather than hard-coding an OS.
    static func mobileSafariUserAgent(from userAgent: String, version: OperatingSystemVersion) -> String? {
        guard userAgent.contains("AppleWebKit/"),
              ["iPhone", "iPad", "iPod"].contains(where: userAgent.contains) else { return nil }
        let mobile = userAgent.range(of: #"\bMobile/\S+"#, options: .regularExpression)
            .map { String(userAgent[$0]) } ?? "Mobile/15E148"
        let base = userAgent.replacingOccurrences(of: #"\s(?:Version|Mobile|Safari|Achaar)/\S+"#,
                                                  with: "", options: .regularExpression)
        return base + " Version/\(version.majorVersion).\(version.minorVersion) " + mobile + " Safari/604.1"
    }

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
              !["accounts", "challenge", "checkpoint", "oauth", "direct", "notifications", "activity", "archive", "create"].contains(
                url.path.split(separator: "/").first.map(String.init) ?? ""),
              !url.path.split(separator: "/").contains("saved") else { return nil }
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
