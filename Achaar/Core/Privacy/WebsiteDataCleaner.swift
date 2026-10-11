import WebKit

@MainActor
enum WebsiteDataCleaner {
    static func clear(in store: WKWebsiteDataStore, includeSession: Bool) async {
        let types = includeSession ? WKWebsiteDataStore.allWebsiteDataTypes() : Set([
            WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache
        ])
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
    }
}
