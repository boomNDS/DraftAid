import Foundation

struct HistoryItem: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let mode: String
    let original: String
    let result: String
    var promptTokens: Int? = nil
    var completionTokens: Int? = nil
    var totalTokens: Int? = nil
}

class LocalStorage {
    static let shared = LocalStorage()
    
    private var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("DraftAid", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }
    
    func save(_ items: [HistoryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL)
        }
    }
    
    func load() -> [HistoryItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }
}
