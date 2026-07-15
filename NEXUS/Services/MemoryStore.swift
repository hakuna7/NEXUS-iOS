import Foundation

actor MemoryStore {
    private let fileURL: URL
    private var cache: [ScreenSnapshot] = []

    init() {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("nexus-screen-memory.json")
    }

    func load() -> [ScreenSnapshot] {
        if !cache.isEmpty { return cache }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ScreenSnapshot].self, from: data) else {
            return []
        }
        cache = decoded
        return cache
    }

    func append(_ snapshot: ScreenSnapshot) -> [ScreenSnapshot] {
        if cache.isEmpty {
            cache = load()
        }
        cache.insert(snapshot, at: 0)
        if cache.count > 500 {
            cache.removeLast(cache.count - 500)
        }
        persist()
        return cache
    }

    func clear() {
        cache.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
