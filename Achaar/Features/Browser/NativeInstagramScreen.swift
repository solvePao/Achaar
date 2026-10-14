import SwiftUI
import WebKit
import AVKit

struct NativeInstagramItem: Decodable, Identifiable, Equatable {
    let id: String
    let kind: String
    let text: String
    let disabled: Bool
    var value: String?
    var source: URL?
    var selected: Bool?
    var aspectRatio: Double?
}

struct NativeInstagramPost: Decodable, Identifiable, Equatable {
    let id: String
    let author: NativeInstagramItem?
    let media: [NativeInstagramItem]
    let actions: [NativeInstagramItem]
    let caption: String
    var commentsLink: NativeInstagramItem?
}

struct NativeInstagramComment: Decodable, Identifiable, Equatable {
    let id: String
    let author: NativeInstagramItem
    let text: String
    let actions: [NativeInstagramItem]
    var timestamp: String?
}

struct NativeInstagramProfile: Decodable, Equatable {
    let username: String
    let avatar: URL?
    let stats: [NativeInstagramItem]
    let about: [String]
    let actions: [NativeInstagramItem]
    let highlights: [NativeInstagramItem]
    let tabs: [NativeInstagramItem]
    let grid: [NativeInstagramItem]
}

struct NativeInstagramSnapshot: Decodable, Equatable {
    let page: String
    let title: String
    let fallback: Bool
    let items: [NativeInstagramItem]
    var posts: [NativeInstagramPost]?
    var comments: [NativeInstagramComment]?
    var storyAuthor: NativeInstagramItem?
    var profile: NativeInstagramProfile?
    var navigationAvatar: URL?
    var commentEditor: NativeInstagramItem?
    var commentMore: NativeInstagramItem?
    var searching: Bool?
}

// Rendered website content stays in memory and is discarded when locked,
// backgrounded, navigated, or switched back to the original website.
struct NativeInstagramScreen: View {
    let browser: BrowserModel
    let enabled: Bool
    let openWeb: () -> Void
    let openSettings: () -> Void
    @State private var snapshot: NativeInstagramSnapshot?
    @State private var playing: NativeInstagramItem?
    @State private var editing: NativeInstagramItem?
    @State private var draft = ""
    @FocusState private var editorFocused: Bool
    @State private var busy = false
    @State private var status: String?
    @State private var webIdentity: ObjectIdentifier?

    var body: some View {
        Group {
            if let snapshot, snapshot.title == "Stories", !snapshot.fallback { storyView(snapshot) }
            else { standardScreen }
        }
        .background(background).tint(.primary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("instagram.native")
        .task(id: "\(enabled)-\(ObjectIdentifier(browser.webView))") {
            guard enabled else { clear(); return }
            let web = browser.webView
            webIdentity = ObjectIdentifier(web)
            while !Task.isCancelled {
                if editing == nil && playing == nil && !busy { await refresh(from: web) }
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
            clear()
        }
        .onChange(of: playing?.id) { _, id in
            if id == nil && enabled && browser.isPresentationAllowed {
                browser.webView.setAllMediaPlaybackSuspended(false, completionHandler: nil)
            }
        }
        .sheet(item: $playing) { item in
            if let source = item.source { NativeInstagramVideo(source: source, openWeb: openWeb) }
        }
        .sheet(item: $editing) { item in editorSheet(item) }
    }

    private var standardScreen: some View {
        VStack(spacing: 0) {
            HStack {
                if snapshot?.title != "Home" {
                    Button { if snapshot?.title == "Search" { changeSearch(open: false) } else { browser.goBack() } } label: { Image(systemName: "chevron.backward") }
                        .accessibilityLabel("Back").disabled(!browser.canGoBack || busy)
                }
                if snapshot?.title == "Home" {
                    Image("InstagramWordmark").renderingMode(.template).resizable().scaledToFit().frame(width: 103, height: 26).accessibilityLabel("Instagram").frame(maxWidth: .infinity, alignment: .leading)
                } else { Text(snapshot?.title ?? "Instagram").font(.headline).frame(maxWidth: .infinity) }
                if snapshot?.title == "Home" {
                    Button { browser.perform(.activity) } label: { Image(systemName: "heart").font(.system(size: 23)) }
                        .accessibilityLabel("Activity")
                }
                Menu {
                    Section("Instagram") {
                        ForEach(WebAction.allCases) { action in
                            Button(action.title, systemImage: action.symbol) { browser.perform(action) }
                        }
                    }
                    Button("Open this screen in Instagram", systemImage: "globe", action: openWeb)
                    Button("Achaar Settings", systemImage: "gearshape", action: openSettings)
                    Button("Refresh", systemImage: "arrow.clockwise") { browser.refresh() }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Screen options")
            }
            .padding(.horizontal, 16).frame(height: 52).background(background)
            if let snapshot, !snapshot.fallback {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: snapshot.title == "Comments" ? 0 : 12) {
                            Color.clear.frame(height: 1).id("top")
                            if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
                            if !stories(snapshot).isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 16) {
                                        ForEach(stories(snapshot)) { item in
                                            Button { act(item, page: snapshot.page, operation: "activate") } label: {
                                                VStack(spacing: 6) {
                                                    if let source = item.source {
                                                        NativeInstagramImage(source: source)
                                                            .frame(width: 66, height: 66).clipShape(Circle())
                                                            .padding(3).overlay(Circle().strokeBorder(AngularGradient(colors: item.text.contains("not seen") ? [.purple, .pink, .orange, .yellow, .pink, .purple] : [.gray, .gray], center: .center), lineWidth: 2.5))
                                                    }
                                                    Text(storyName(item.text)).font(.system(size: 12)).lineLimit(1).frame(width: 76)
                                                }
                                            }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier("native.story.\(item.id)")
                                        }
                                    }.padding(.horizontal, 12).padding(.vertical, 8)
                                }
                                Divider()
                            }
                            if snapshot.title == "Search" { searchView(snapshot) }
                            else if let profile = snapshot.profile { profileView(profile, page: snapshot.page) }
                            else if let comments = snapshot.comments, !comments.isEmpty {
                                ForEach(comments) { comment in commentView(comment, page: snapshot.page) }
                                ForEach(snapshot.items.filter { $0.text.lowercased().hasPrefix("view replies") }) { item in
                                    itemView(item, page: snapshot.page)
                                }
                                if let more = snapshot.commentMore {
                                    Button { act(more, page: snapshot.page, operation: "activate") } label: {
                                        Image(systemName: "plus.circle").font(.system(size: 26)).frame(height: 52)
                                    }.accessibilityLabel("Load more comments")
                                }
                            } else if let posts = snapshot.posts, !posts.isEmpty {
                                ForEach(posts) { post in postView(post, page: snapshot.page) }
                            } else {
                            ForEach(blocks(snapshot)) { block in
                                if block.items.count > 1 {
                                    HStack(spacing: 14) {
                                        ForEach(block.items) { item in
                                            if item.text.lowercased().contains("save") { Spacer(minLength: 0) }
                                            compactAction(item, page: snapshot.page)
                                        }
                                    }.padding(.horizontal, 12).padding(.vertical, 4)
                                } else if let item = block.items.first {
                                    itemView(item, page: snapshot.page)
                                }
                            }
                            }
                            if snapshot.title != "Comments", snapshot.profile == nil, snapshot.title != "Search" {
                                HStack {
                                    Button("Previous page") { scroll(-1) }
                                    Spacer()
                                    Button("Load more") { scroll(1) }
                                }.font(.footnote).padding(.horizontal, 12).disabled(busy)
                            }
                        }.padding(.bottom, 16)
                    }
                    .accessibilityIdentifier("native.content")
                    .onChange(of: snapshot.page) { _, _ in proxy.scrollTo("top", anchor: .top) }
                }
            } else {
                ContentUnavailableView {
                    Label(snapshot == nil ? "Loading Instagram" : "Continue in Instagram", systemImage: "globe")
                } description: {
                    Text("Login, uploads, and unsupported controls use the signed-in website.")
                } actions: {
                    Button("Open Instagram", action: openWeb)
                }
            }
            Divider()
            if snapshot?.title == "Comments" {
                if let editor = snapshot?.commentEditor {
                HStack {
                    Button {
                        editing = editor; draft = editor.value ?? ""
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "face.smiling").font(.system(size: 24))
                            Text(editor.value?.isEmpty == false ? editor.value! : editor.text).font(.system(size: 14)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(.horizontal, 16).frame(minHeight: 52)
                    }.accessibilityLabel("Add a comment")
                }.background(background)
                } else {
                    Button("Continue commenting in Instagram", action: openWeb).font(.system(size: 14)).frame(height: 52)
                }
            } else {
            HStack {
                ForEach([InstagramTab.home, .explore, .reels]) { tab in tabButton(tab) }
                Button { browser.perform(.create) } label: {
                    Image(systemName: "plus.app").font(.system(size: 25)).frame(maxWidth: .infinity).frame(height: 48)
                }.accessibilityLabel("Create")
                ForEach([InstagramTab.messages, .profile]) { tab in tabButton(tab) }
            }.foregroundStyle(.primary).background(background).disabled(busy)
            }

        }
    }

    private func editorSheet(_ item: NativeInstagramItem) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let status { Text(status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 12) }
                TextEditor(text: $draft).font(.system(size: 15)).frame(minHeight: 100).focused($editorFocused).disabled(busy)
                    .accessibilityLabel(item.text).padding(.horizontal, 12)
                HStack {
                    Button("Cancel") { editing = nil; draft = "" }
                    Spacer()
                    Button("Apply draft") { finishEditing(item, submit: false) }.disabled(busy || draft.count > 10_000)
                    if snapshot?.title != "Search" && !item.text.lowercased().contains("search") {
                        Button(snapshot?.title == "Comments" ? "Post" : "Send") { finishEditing(item, submit: true) }
                            .fontWeight(.semibold).foregroundStyle(.blue)
                            .disabled(busy || draft.count > 10_000 || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(.horizontal, 16)
                if status != nil {
                    HStack {
                        Button("Copy draft") { UIPasteboard.general.string = draft }
                        Spacer()
                        Button("Open Instagram") { editing = nil; openWeb() }
                    }.font(.footnote).padding(.horizontal, 16)
                }
            }
            .navigationTitle(item.text).navigationBarTitleDisplayMode(.inline)
            .padding(.vertical).onAppear { editorFocused = true }.onDisappear { editorFocused = false }
        }.presentationDetents([.medium]).presentationDragIndicator(.visible)
    }
    private func finishEditing(_ item: NativeInstagramItem, submit: Bool) {
        let page = snapshot?.page
        let value = draft
        if let page { act(item, page: page, operation: submit ? "compose" : "edit", value: value) }
    }

    private func storyView(_ snapshot: NativeInstagramSnapshot) -> some View {
        VStack(spacing: 12) {
            Capsule().fill(.white.opacity(0.7)).frame(height: 2).padding(.horizontal, 8)
            HStack {
                Text(snapshot.storyAuthor?.text ?? "Story")
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Spacer()
                if let menu = snapshot.items.first(where: { $0.text == "Menu" }) {
                    Button { act(menu, page: snapshot.page, operation: "activate") } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("Story menu")
                }
                Button {
                    if let close = snapshot.items.first(where: { $0.text == "Close" }) { act(close, page: snapshot.page, operation: "activate") }
                    else { browser.goBack() }
                } label: { Image(systemName: "xmark").font(.system(size: 23)) }.accessibilityLabel("Close story")
            }.padding(.horizontal, 16)
            Spacer(minLength: 0)
            if let media = snapshot.items.first(where: { ["image","video","web"].contains($0.kind) }) {
                postMedia(media).frame(maxHeight: .infinity)
            }
            Spacer(minLength: 0)
            if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
            HStack(spacing: 18) {
                if let editor = snapshot.items.first(where: { $0.kind == "editor" }) {
                    Button { editing = editor; draft = editor.value ?? "" } label: {
                        Text(editor.text).font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).frame(height: 44)
                            .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                    }.accessibilityLabel("Reply to story")
                }
                ForEach(snapshot.items.filter { ["Like","Unlike","Direct"].contains($0.text) }) { item in
                    compactAction(item, page: snapshot.page)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }.background(.black).foregroundStyle(.white).disabled(busy)
    }

    @ViewBuilder private func itemView(_ item: NativeInstagramItem, page: String) -> some View {
        switch item.kind {
        case "image":
            if let source = item.source, Self.allowedMedia(source) {
                NativeInstagramImage(source: source)
                .frame(maxWidth: .infinity, maxHeight: 460).clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(item.text)
            }
        case "video":
            Button(item.text, systemImage: "play.rectangle") {
                guard let source = item.source, Self.allowedMedia(source) else { openWeb(); return }
                browser.webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
                playing = item
            }.buttonStyle(.bordered)
        case "action":
            Button { act(item, page: page, operation: "activate") } label: {
                VStack(alignment: .leading, spacing: 8) {
                    if let source = item.source, Self.allowedMedia(source) {
                        NativeInstagramImage(source: source).frame(maxHeight: 440).clipped()
                    }
                    HStack {
                        if let symbol = actionSymbol(item.text) { Image(systemName: symbol).font(.system(size: 23)) }
                        Text(item.text).font(.system(size: 14)).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if item.selected == true { Image(systemName: "checkmark") }
                    }.frame(minHeight: 36).padding(.horizontal, 12)
                }
            }
            .buttonStyle(.plain).foregroundStyle(.primary).disabled(item.disabled || busy)
            .accessibilityIdentifier("native.action.\(item.id)")
        case "editor":
            Button {
                editing = item; draft = item.value ?? ""
            } label: {
                Label(item.value?.isEmpty == false ? "\(item.text): \(item.value!)" : item.text, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
            }.buttonStyle(.bordered).disabled(item.disabled || busy)
        case "web":
            Button(item.text, systemImage: "globe", action: openWeb).buttonStyle(.bordered)
        default:
            Text(item.text).font(.system(size: 14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12)
        }
    }

    private func searchView(_ snapshot: NativeInstagramSnapshot) -> some View {
        VStack(spacing: 4) {
            if snapshot.searching == true, let editor = snapshot.items.first(where: { $0.kind == "editor" && $0.text.lowercased().contains("search") }) {
                NativeInstagramSearchField(item: editor, busy: busy) { value in
                    act(editor, page: snapshot.page, operation: "edit", value: value)
                }.id(editor.id).padding(.horizontal, 12).padding(.bottom, 12)
                ForEach(snapshot.items.filter { $0.kind == "action" && !["back","clear the search box","search"].contains($0.text.lowercased()) }) { item in
                    Button { act(item, page: snapshot.page, operation: "activate") } label: {
                        HStack(spacing: 12) {
                            if let source = item.source { NativeInstagramImage(source: source).frame(width: 44, height: 44).clipShape(Circle()) }
                            else { Image(systemName: "magnifyingglass").frame(width: 44, height: 44).foregroundStyle(.secondary) }
                            Text(item.text).font(.system(size: 14)).multilineTextAlignment(.leading).lineLimit(2)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 16).frame(minHeight: 60)
                    }.buttonStyle(.plain).disabled(item.disabled || busy)
                }
            } else {
                Button { changeSearch(open: true) } label: {
                    Label("Search", systemImage: "magnifyingglass").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).frame(height: 38)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                }.padding(.horizontal, 12).padding(.bottom, 8).accessibilityIdentifier("native.search.open")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(snapshot.items.filter { $0.kind == "action" && $0.source != nil }) { item in
                        Button { act(item, page: snapshot.page, operation: "activate") } label: {
                            if let source = item.source { GeometryReader { geometry in
                            NativeInstagramImage(source: source, mode: .fill).frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }.aspectRatio(0.8, contentMode: .fit) }
                        }.accessibilityLabel(item.text)
                    }
                }
            }
        }
    }

    private func profileView(_ profile: NativeInstagramProfile, page: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                if let avatar = profile.avatar { NativeInstagramImage(source: avatar).frame(width: 84, height: 84).clipShape(Circle()) }
                HStack(spacing: 16) {
                    ForEach(profile.stats) { stat in
                        Button {
                            if stat.kind == "action" { act(stat, page: page, operation: "activate") }
                        } label: {
                            VStack(spacing: 3) {
                                Text(stat.text.components(separatedBy: " ").dropLast().joined(separator: " ")).font(.system(size: 16, weight: .semibold))
                                Text(stat.text.components(separatedBy: " ").last ?? "").font(.system(size: 12))
                            }
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(profile.about.enumerated()), id: \.offset) { _, line in Text(line).font(.system(size: 14)) }
            }.padding(.horizontal, 16)
            HStack(spacing: 8) {
                ForEach(profile.actions.filter { $0.text.lowercased() != "options" }) { action in
                    Button(action.text) { act(action, page: page, operation: "activate") }
                        .font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 34)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                }
            }.padding(.horizontal, 12)
            if !profile.highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(profile.highlights) { highlight in
                            Button { act(highlight, page: page, operation: "activate") } label: {
                                VStack(spacing: 6) {
                                    if let source = highlight.source { NativeInstagramImage(source: source).frame(width: 62, height: 62).clipShape(Circle()).padding(3).overlay(Circle().stroke(.gray.opacity(0.5), lineWidth: 1)) }
                                    Text(highlight.text.replacingOccurrences(of: "View ", with: "").replacingOccurrences(of: " highlight", with: "")).font(.system(size: 12)).lineLimit(1).frame(width: 72)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 12)
                }
            }
            HStack {
                ForEach(profile.tabs) { tab in
                    Button { act(tab, page: page, operation: "activate") } label: {
                        Image(systemName: profileTabSymbol(tab.text)).font(.system(size: 23)).frame(maxWidth: .infinity).frame(height: 40)
                    }.accessibilityLabel(tab.text)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(profile.grid) { item in
                    Button { act(item, page: page, operation: "activate") } label: {
                        if let source = item.source { GeometryReader { geometry in
                            NativeInstagramImage(source: source, mode: .fill).frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }.aspectRatio(0.75, contentMode: .fit) }
                        else { Color.secondary.opacity(0.1).aspectRatio(0.75, contentMode: .fit).overlay(Image(systemName: "play.rectangle")) }
                    }.accessibilityLabel(item.text)
                }
            }
        }.disabled(busy).foregroundStyle(.primary)
    }
    private func profileTabSymbol(_ value: String) -> String {
        switch value.lowercased() { case "posts": "square.grid.3x3"; case "reels": "play.rectangle"; case "saved": "bookmark"; case "reposts": "arrow.2.squarepath"; default: "person.crop.rectangle" }
    }

    private func commentView(_ comment: NativeInstagramComment, page: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let source = comment.author.source {
                NativeInstagramImage(source: source).frame(width: 34, height: 34).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 6) {
                if comment.author.kind == "action" {
                    Button(comment.author.text) { act(comment.author, page: page, operation: "activate") }
                        .font(.system(size: 13, weight: .semibold)).buttonStyle(.plain)
                } else if !comment.author.text.isEmpty { Text(comment.author.text).font(.system(size: 13, weight: .semibold)) }
                Text(comment.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    if let timestamp = comment.timestamp { Text(timestamp).font(.system(size: 12)).foregroundStyle(.secondary) }
                    ForEach(comment.actions.filter { !["like","unlike","comment options"].contains($0.text.lowercased()) }) { action in
                        Button(action.text) { act(action, page: page, operation: "activate") }
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let like = comment.actions.first(where: { ["like","unlike"].contains($0.text.lowercased()) }) {
                Button { act(like, page: page, operation: "activate") } label: {
                    Image(systemName: like.text.lowercased() == "like" ? "heart" : "heart.fill").font(.system(size: 13))
                }.accessibilityLabel(like.text)
            }
        }.padding(.horizontal, 16).padding(.vertical, 8).disabled(busy)
        .contextMenu {
            ForEach(comment.actions.filter { $0.text.lowercased() == "comment options" }) { action in
                Button("Comment options") { act(action, page: page, operation: "activate") }
            }
        }
    }

    private func postView(_ post: NativeInstagramPost, page: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let author = post.author {
                    Button { act(author, page: page, operation: "activate") } label: {
                        HStack(spacing: 10) {
                            if let source = author.source {
                                NativeInstagramImage(source: source).frame(width: 32, height: 32).clipShape(Circle())
                            }
                            Text(author.text).font(.system(size: 14, weight: .semibold))
                        }
                    }.buttonStyle(.plain)
                }
                Spacer()
                if let more = post.actions.first(where: { $0.text.lowercased() == "more options" }) {
                    Button { act(more, page: page, operation: "activate") } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("More options")
                }
            }.padding(.horizontal, 12).frame(minHeight: 44)
            if post.media.count > 1 {
                GeometryReader { geometry in
                    TabView { ForEach(post.media) { item in postMedia(item) } }
                        .tabViewStyle(.page).frame(width: geometry.size.width, height: geometry.size.height)
                }.aspectRatio(post.media.first?.aspectRatio ?? 1, contentMode: .fit)
            } else if let item = post.media.first { postMedia(item) }
            HStack(spacing: 18) {
                ForEach(post.actions.filter { $0.text.lowercased() != "more options" }) { item in
                    if item.text.lowercased().contains("save") { Spacer(minLength: 0) }
                    compactAction(item, page: page)
                }
            }.padding(.horizontal, 12).frame(minHeight: 36)
            if !post.caption.isEmpty {
                Text(post.caption).font(.system(size: 14)).lineSpacing(3).padding(.horizontal, 12)
            }
            if let commentsLink = post.commentsLink {
                Button(commentsLink.text) { act(commentsLink, page: page, operation: "activate") }
                    .font(.system(size: 14)).foregroundStyle(.secondary).padding(.horizontal, 12)
            }
            Divider().padding(.top, 8)
        }.foregroundStyle(.primary).disabled(busy)
    }
    @ViewBuilder private func postMedia(_ item: NativeInstagramItem) -> some View {
        if item.kind == "image", let source = item.source {
            NativeInstagramImage(source: source).aspectRatio(item.aspectRatio ?? 1, contentMode: .fit)
                .frame(maxWidth: .infinity).accessibilityLabel(item.text)
        } else {
            Button { if item.kind == "video" { browser.webView.setAllMediaPlaybackSuspended(true, completionHandler: nil); playing = item } else { openWeb() } } label: {
                ZStack { Color.black; Image(systemName: "play.circle").font(.system(size: 48)).foregroundStyle(.white) }
                    .aspectRatio(item.aspectRatio ?? 0.8, contentMode: .fit)
            }.accessibilityLabel("Play video")
        }
    }

    private var background: Color { Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 15/255, green: 16/255, blue: 20/255, alpha: 1) : .white }) }
    private func stories(_ snapshot: NativeInstagramSnapshot) -> [NativeInstagramItem] { snapshot.items.filter { $0.kind == "story" } }
    private func storyName(_ value: String) -> String {
        value.replacingOccurrences(of: "Story by ", with: "").components(separatedBy: ",").first ?? value
    }
    private struct Block: Identifiable {
        let items: [NativeInstagramItem]
        var id: String { items.first!.id }
    }
    private func blocks(_ snapshot: NativeInstagramSnapshot) -> [Block] {
        var result: [Block] = []
        var actions: [NativeInstagramItem] = []
        for item in snapshot.items where item.kind != "story" {
            let compact = item.kind == "action" && (actionSymbol(item.text) != nil || Double(item.text) != nil)
            if compact { actions.append(item) }
            else {
                if !actions.isEmpty { result.append(Block(items: actions)); actions = [] }
                result.append(Block(items: [item]))
            }
        }
        if !actions.isEmpty { result.append(Block(items: actions)) }
        return result
    }
    private func actionSymbol(_ value: String) -> String? {
        switch value.lowercased() {
        case "like": "heart"
        case "unlike": "heart.fill"
        case "comment", "comments": "bubble"
        case "share", "share post", "direct": "paperplane"
        case "save": "bookmark"
        case "unsave", "remove from saved": "bookmark.fill"
        case "repost": "arrow.2.squarepath"
        default: nil
        }
    }
    private func compactAction(_ item: NativeInstagramItem, page: String) -> some View {
        Button { act(item, page: page, operation: "activate") } label: {
            if let symbol = actionSymbol(item.text) { Image(systemName: symbol).font(.system(size: 24)) }
            else { Text(item.text).font(.system(size: 13, weight: .semibold)) }
        }.buttonStyle(.plain).accessibilityLabel(item.text).disabled(item.disabled || busy)
    }
    private func tabButton(_ tab: InstagramTab) -> some View {
        Button { browser.select(tab) } label: {
            Group {
                if tab == .profile, let avatar = snapshot?.navigationAvatar {
                    NativeInstagramImage(source: avatar).frame(width: 25, height: 25).clipShape(Circle())
                        .padding(3).overlay(Circle().stroke(browser.selectedTab == .profile ? Color.primary : .clear, lineWidth: 1.5))
                } else { Image(systemName: browser.selectedTab == tab ? selectedSymbol(tab) : tab.symbol).font(.system(size: 24)) }
            }.frame(maxWidth: .infinity).frame(height: 48)
        }.accessibilityLabel(tab.title).accessibilityIdentifier("native.tab.\(tab.rawValue)")
            .accessibilityAddTraits(browser.selectedTab == tab ? [.isSelected] : [])
    }
    private func selectedSymbol(_ tab: InstagramTab) -> String {
        switch tab { case .home: "house.fill"; case .explore: "magnifyingglass"; case .reels: "play.rectangle.fill"; case .messages: "paperplane.fill"; case .profile: "person.crop.circle.fill" }
    }

    private static func allowedMedia(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, let host = url.host else { return false }
        return ["cdninstagram.com", "fbcdn.net"].contains { host == $0 || host.hasSuffix(".\($0)") }
    }
    @MainActor private func refresh(from web: WKWebView) async {
        guard enabled, browser.isPresentationAllowed, !browser.isClearing, web === browser.webView,
              InstagramRouting.isInstagram(web.url), !browser.isLoading else { snapshot = nil; return }
        let url = web.url
        do {
            let result = try await web.evaluateJavaScript("JSON.stringify(window.AchaarNative?.snapshot() ?? null)")
            guard !Task.isCancelled, enabled, browser.isPresentationAllowed, !browser.isClearing,
                  web === browser.webView, web.url == url, let string = result as? String,
                  let data = string.data(using: .utf8) else { return }
            let next = try JSONDecoder().decode(NativeInstagramSnapshot.self, from: data)
            if next.title == "Stories", !next.fallback, next.items.contains(where: { $0.kind == "web" && $0.text == "Play video" }) {
                snapshot = nil; openWeb(); return
            }
            if snapshot != next { snapshot = next }
        } catch {
            snapshot = nil
            status = "This screen needs Instagram’s web interface."
        }
    }
    private func act(_ item: NativeInstagramItem, page: String, operation: String, value: String = "") {
        guard enabled, !busy, browser.isPresentationAllowed, !browser.isClearing,
              webIdentity == ObjectIdentifier(browser.webView) else { return }
        busy = true
        let web = browser.webView
        Task { @MainActor in
            defer { busy = false }
            guard browser.isPresentationAllowed, !browser.isClearing, web === browser.webView else { return }
            do {
                let result = try await web.callAsyncJavaScript(
                    "return operation === 'compose' ? await window.AchaarNative?.compose({page,id,value}) : window.AchaarNative?.act({page,id,operation,value}) ?? 'unsupported';",
                    arguments: ["page":page,"id":item.id,"operation":operation,"value":value], in: nil, contentWorld: .page)
                guard enabled, browser.isPresentationAllowed, !browser.isClearing, web === browser.webView else { return }
                switch result as? String {
                case "dispatched":
                    status = nil
                    if ["edit", "compose"].contains(operation), editing?.id == item.id { editing = nil; draft = "" }
                case "stale": status = "The page changed. Review the refreshed controls and try again."
                case "draftOnly": status = "Draft applied. Open Instagram to finish sending."
                case "disabled": status = "This control is currently unavailable."
                default: status = "Use Open Instagram for this control."
                }
                await refresh(from: web)
                if operation == "activate", item.text.lowercased() == "reply", let editor = snapshot?.commentEditor {
                    editing = editor; draft = editor.value ?? ""
                }
            } catch { status = "Couldn’t use this control. Open Instagram to continue." }
        }
    }
    private func changeSearch(open: Bool) {
        guard enabled, !busy, browser.isPresentationAllowed, !browser.isClearing else { return }
        let web = browser.webView
        Task { @MainActor in
            guard browser.isPresentationAllowed, !browser.isClearing, web === browser.webView else { return }
            let result = try? await web.callAsyncJavaScript("return open ? window.AchaarNative?.openSearch() : window.AchaarNative?.closeSearch();",
                arguments: ["open": open], in: nil, contentWorld: .page)
            if result as? Bool != true {
                if open { status = "Open Instagram to use search on this screen." }
                else { browser.goBack() }
            }
            await refresh(from: web)
        }
    }

    private func scroll(_ direction: Int) {
        guard enabled, !busy, browser.isPresentationAllowed, !browser.isClearing else { return }
        let web = browser.webView
        Task { @MainActor in
            guard browser.isPresentationAllowed, !browser.isClearing, web === browser.webView else { return }
            _ = try? await web.callAsyncJavaScript("return window.AchaarNative?.scroll(direction) ?? false;",
                                                  arguments: ["direction":direction], in: nil, contentWorld: .page)
            await refresh(from: web)
        }
    }
    private func clear() {
        snapshot = nil; editing = nil; playing = nil; draft = ""; status = nil; webIdentity = nil
    }
}

// Do not use the shared URL cache or copy WebKit cookies for private media.
private struct NativeInstagramImage: View {
    let source: URL
    var mode: ContentMode = .fit
    @State private var image: UIImage?
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: mode) }
            else { Image(systemName: "photo").frame(height: 100).foregroundStyle(.secondary) }
        }.task(id: source) {
            image = nil
            guard let (data, response) = try? await Self.session.data(from: source), !Task.isCancelled,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= 12 * 1024 * 1024 else { return }
            image = UIImage(data: data)
        }
    }
}

private struct NativeInstagramVideo: View {
    let source: URL
    let openWeb: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    var body: some View {
        NavigationStack {
            VStack {
                VideoPlayer(player: player)
                Button("Playback problem? Open Instagram") { dismiss(); openWeb() }
                    .padding()
            }
            .navigationTitle("Video")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: source) { player = AVPlayer(url: source); player?.play() }
            .onDisappear { player?.pause(); player = nil }
        }
    }
}

private struct NativeInstagramSearchField: View {
    let item: NativeInstagramItem
    let busy: Bool
    let edit: (String) -> Void
    @State private var query: String
    init(item: NativeInstagramItem, busy: Bool, edit: @escaping (String) -> Void) {
        self.item = item; self.busy = busy; self.edit = edit
        _query = State(initialValue: item.value ?? "")
    }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: $query).font(.system(size: 15)).submitLabel(.search)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("native.search")
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("Clear search") }
        }.padding(.horizontal, 12).frame(height: 38)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
        .task(id: "\(query)-\(busy)-\(item.value ?? "")") {
            guard !busy, query != (item.value ?? "") else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled else { return }
            edit(query)
        }
    }
}
