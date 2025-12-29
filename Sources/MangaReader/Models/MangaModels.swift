import Foundation

struct Manga: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let coverArt: URL
    let authors: [String]
    let tags: [String]
    let status: String
    let rating: Double?
    let chapters: [Chapter]
    var torboxFileId: String?
    var isFavorite: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, coverArt, authors, tags, status, rating, chapters, torboxFileId, isFavorite
    }
}

struct Chapter: Identifiable, Codable, Hashable {
    let id: String
    let number: Double
    let title: String?
    let pages: [URL]
    var isDownloaded: Bool = false
    let publishDate: Date
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, pages, isDownloaded, publishDate, language
    }
}

struct TorboxFile: Identifiable, Codable {
    let id: String
    let name: String
    let size: Int64
    let downloadUrl: URL
    let torrentHash: String?
    let createdAt: Date
    let status: String
}

struct Torrent: Identifiable, Codable {
    let id: String
    let name: String
    let hash: String
    let size: Int64
    let progress: Double
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let status: String
    let createdAt: Date
    let files: [TorrentFile]
    let webDavLink: String?
}

struct TorrentFile: Identifiable, Codable {
    let id: String
    let name: String
    let size: Int64
    let path: String
}

struct ReadingProgress: Identifiable, Codable {
    let id: String
    let mangaId: String
    let chapterId: String
    let lastPageRead: Int
    let totalPages: Int
    let lastReadDate: Date
    let isCompleted: Bool
}

struct Bookmark: Identifiable, Codable {
    let id: String
    let mangaId: String
    let chapterId: String
    let pageNumber: Int
    let note: String?
    let createdAt: Date
}

enum ReadingMode: String, CaseIterable, Codable {
    case vertical = "vertical"
    case horizontal = "horizontal"
}

struct AppSettings: Codable {
    var torboxApiKey: String?
    var mangadexApiKey: String?
    var readingMode: ReadingMode = .vertical
    var autoDownload: Bool = false
    var downloadQuality: String = "high"
}
