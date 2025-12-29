import Foundation

class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private let keys = (
        readingMode: "readingMode",
        autoDownload: "autoDownload",
        downloadQuality: "downloadQuality",
        lastReadManga: "lastReadManga",
        libraryManga: "libraryManga",
        favoriteManga: "favoriteManga"
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
    
    @Published var libraryMangaIds: Set<String> {
        didSet {
            userDefaults.set(Array(libraryMangaIds), forKey: keys.libraryManga)
        }
    }
    
    @Published var favoriteMangaIds: Set<String> {
        didSet {
            userDefaults.set(Array(favoriteMangaIds), forKey: keys.favoriteManga)
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
        self.libraryMangaIds = Set(userDefaults.stringArray(forKey: keys.libraryManga) ?? [])
        self.favoriteMangaIds = Set(userDefaults.stringArray(forKey: keys.favoriteManga) ?? [])
    }
    
    func addToLibrary(mangaId: String) {
        libraryMangaIds.insert(mangaId)
    }
    
    func removeFromLibrary(mangaId: String) {
        libraryMangaIds.remove(mangaId)
        favoriteMangaIds.remove(mangaId)
    }
    
    func isInLibrary(mangaId: String) -> Bool {
        libraryMangaIds.contains(mangaId)
    }
    
    func toggleFavorite(mangaId: String) {
        if favoriteMangaIds.contains(mangaId) {
            favoriteMangaIds.remove(mangaId)
        } else {
            favoriteMangaIds.insert(mangaId)
            libraryMangaIds.insert(mangaId) // Also add to library
        }
    }
    
    func isFavorite(mangaId: String) -> Bool {
        favoriteMangaIds.contains(mangaId)
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
