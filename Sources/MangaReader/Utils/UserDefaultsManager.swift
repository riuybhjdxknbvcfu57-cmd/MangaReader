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
        favoriteManga: "favoriteManga",
        torboxDownloads: "torboxDownloads"
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
    
    @Published var torboxDownloads: [TorboxDownload] {
        didSet {
            if let data = try? JSONEncoder().encode(torboxDownloads) {
                userDefaults.set(data, forKey: keys.torboxDownloads)
            }
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
        
        if let data = userDefaults.data(forKey: keys.torboxDownloads),
           let downloads = try? JSONDecoder().decode([TorboxDownload].self, from: data) {
            self.torboxDownloads = downloads
        } else {
            self.torboxDownloads = []
        }
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
            libraryMangaIds.insert(mangaId)
        }
    }
    
    func isFavorite(mangaId: String) -> Bool {
        favoriteMangaIds.contains(mangaId)
    }
    
    func saveTorboxDownload(mangaId: String, torrentHash: String, torrentName: String) {
        let download = TorboxDownload(
            mangaId: mangaId,
            torrentHash: torrentHash,
            torrentName: torrentName,
            addedAt: Date()
        )
        if !torboxDownloads.contains(where: { $0.torrentHash == torrentHash }) {
            torboxDownloads.append(download)
        }
    }
    
    func getTorboxDownloads(forMangaId mangaId: String) -> [TorboxDownload] {
        torboxDownloads.filter { $0.mangaId == mangaId }
    }
    
    func removeTorboxDownload(hash: String) {
        torboxDownloads.removeAll { $0.torrentHash == hash }
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

struct TorboxDownload: Codable, Identifiable {
    var id: String { torrentHash }
    let mangaId: String
    let torrentHash: String
    let torrentName: String
    let addedAt: Date
}
