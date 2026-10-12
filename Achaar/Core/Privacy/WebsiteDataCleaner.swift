import WebKit

@MainActor
enum WebsiteDataCleaner {
    static let cacheTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache])
    static func clear(in store: WKWebsiteDataStore, includeSession: Bool) async {
        let types = includeSession ? WKWebsiteDataStore.allWebsiteDataTypes() : cacheTypes
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
    }
}

// Measure file metadata only. WebKit does not expose a total website-store size
// or a public byte quota. This is a cleanup budget for observable cached files,
// not a hard cap on cookies, local storage, or the WebKit process's memory.
enum CacheBudget {
    static func bytes(in directory: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let entries = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in entries {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    static func shouldTrim(bytes: Int64, budgetMB: Int) -> Bool {
        budgetMB == 0 || bytes > Int64(budgetMB) * 1_048_576
    }
}
