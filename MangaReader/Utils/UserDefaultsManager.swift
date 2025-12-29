import Foundation

class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private let keys = (
        readingMode: "readingMode",
        autoDownload: "autoDownload",
        downloadQuality: "downloadQuality",
        lastReadManga: "lastReadManga"
    )
    
    @Published var readingMode: ReadingMode {
        didSet {
            userDefaults.set(readingMode.rawValue, forKey: keys.readingMode)
        }
    }
    
    @Published var autoDownload: Bool {
        didSet {
            userDefaults.set(autoDownload, forKey: keys.autoDownload)
        }
    }
    
    @Published var downloadQuality: String {
        didSet {
            userDefaults.set(downloadQuality, forKey: keys.downloadQuality)
        }
    }
    
    var lastReadMangaId: String? {
        get { userDefaults.string(forKey: keys.lastReadManga) }
        set { userDefaults.set(newValue, forKey: keys.lastReadManga) }
    }
    
    private init() {
        self.readingMode = ReadingMode(rawValue: userDefaults.string(forKey: keys.readingMode) ?? "vertical") ?? .vertical
        self.autoDownload = userDefaults.bool(forKey: keys.autoDownload)
        self.downloadQuality = userDefaults.string(forKey: keys.downloadQuality) ?? "high"
    }
    
    func saveReadingProgress(_ progress: ReadingProgress) {
        let key = "readingProgress_\(progress.mangaId)_\(progress.chapterId)"
        if let data = try? JSONEncoder().encode(progress) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func getReadingProgress(mangaId: String, chapterId: String) -> ReadingProgress? {
        let key = "readingProgress_\(mangaId)_\(chapterId)"
        guard let data = userDefaults.data(forKey: key),
              let progress = try? JSONDecoder().decode(ReadingProgress.self, from: data) else {
            return nil
        }
        return progress
    }
    
    func saveBookmarks(_ bookmarks: [Bookmark], mangaId: String) {
        let key = "bookmarks_\(mangaId)"
        if let data = try? JSONEncoder().encode(bookmarks) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func getBookmarks(mangaId: String) -> [Bookmark] {
        let key = "bookmarks_\(mangaId)"
        guard let data = userDefaults.data(forKey: key),
              let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return []
        }
        return bookmarks
    }
}
