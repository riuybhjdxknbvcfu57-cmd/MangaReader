import Foundation

class MangaDexService: ObservableObject {
    static let shared = MangaDexService()
    
    private let baseURL = "https://api.mangadex.org"
    
    private init() {}
    
    func searchManga(query: String, limit: Int = 20, offset: Int = 0) async throws -> [Manga] {
        var components = URLComponents(string: "\(baseURL)/manga")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "title", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(MangaDexResponse.self, from: data)
        
        return response.data.map { $0.toManga() }
    }
    
    func getPopularManga(limit: Int = 20, offset: Int = 0) async throws -> [Manga] {
        var components = URLComponents(string: "\(baseURL)/manga")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "order[followedCount]", value: "desc"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(MangaDexResponse.self, from: data)
        
        return response.data.map { $0.toManga() }
    }
    
    func getSeasonalManga() async throws -> [Manga] {
        let calendar = Calendar.current
        let now = Date()
        
        guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
            return []
        }
        
        let formatter = ISO8601DateFormatter()
        let startDate = formatter.string(from: threeMonthsAgo)
        
        var components = URLComponents(string: "\(baseURL)/manga")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "updatedAtSince", value: startDate),
            URLQueryItem(name: "order[updatedAt]", value: "desc"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(MangaDexResponse.self, from: data)
        
        return response.data.map { $0.toManga() }
    }
    
    func getMangaDetails(id: String) async throws -> Manga {
        var components = URLComponents(string: "\(baseURL)/manga/\(id)")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "includes[]", value: "artist")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(MangaDexDetailResponse.self, from: data)
        
        let manga = response.data.toManga()
        let chapters = try await getChapters(mangaId: id)
        
        return Manga(
            id: manga.id,
            title: manga.title,
            description: manga.description,
            coverArt: manga.coverArt,
            authors: manga.authors,
            tags: manga.tags,
            status: manga.status,
            rating: manga.rating,
            chapters: chapters
        )
    }
    
    func getChapters(mangaId: String, language: String = "en") async throws -> [Chapter] {
        var components = URLComponents(string: "\(baseURL)/manga/\(mangaId)/feed")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "translatedLanguage[]", value: language),
            URLQueryItem(name: "order[chapter]", value: "asc"),
            URLQueryItem(name: "limit", value: "500")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(MangaDexFeedResponse.self, from: data)
        
        return response.data.map { $0.toChapter() }
    }
    
    func getChapterPages(chapterId: String) async throws -> [URL] {
        let url = URL(string: "\(baseURL)/at-home/server/\(chapterId)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(ChapterPagesResponse.self, from: data)
        
        let baseUrl = response.baseUrl
        let hash = response.chapter.hash
        
        let sortedFiles = response.chapter.data.sorted { $0 < $1 }
        
        return sortedFiles.map { fileName in
            URL(string: "\(baseUrl)/data/\(hash)/\(fileName)")!
        }
    }
}

struct MangaDexResponse: Codable {
    let data: [MangaDexManga]
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaDexDetailResponse: Codable {
    let data: MangaDexManga
}

struct MangaDexFeedResponse: Codable {
    let data: [MangaDexChapter]
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaDexManga: Codable {
    let id: String
    let attributes: MangaAttributes
    let relationships: [Relationship]
    
    func toManga() -> Manga {
        var title = ""
        var authors: [String] = []
        var coverUrl: URL?
        var tags: [String] = []
        
        if let titleAttributes = attributes.title.en {
            title = titleAttributes
        } else if let altTitle = attributes.altTitles.first?.values.first {
            title = altTitle
        }
        
        for relationship in relationships {
            switch relationship.type {
            case "author":
                if let authorName = relationship.attributes?.name {
                    authors.append(authorName)
                }
            case "cover_art":
                if let fileName = relationship.attributes?.fileName {
                    coverUrl = URL(string: "https://uploads.mangadex.org/covers/\(id)/\(fileName).512.jpg")
                }
            default:
                break
            }
        }
        
        tags = attributes.tags.map { $0.attributes.name.en }
        
        let defaultCover = URL(string: "https://via.placeholder.com/512")!
        
        return Manga(
            id: id,
            title: title,
            description: attributes.description.en ?? "",
            coverArt: coverUrl ?? defaultCover,
            authors: authors,
            tags: tags,
            status: attributes.status,
            rating: nil,
            chapters: []
        )
    }
}

struct MangaAttributes: Codable {
    let title: [String: String]
    let altTitles: [[String: String]]
    let description: [String: String]
    let status: String
    let tags: [Tag]
}

struct Tag: Codable {
    let id: String
    let attributes: TagAttributes
}

struct TagAttributes: Codable {
    let name: NameObject
}

struct NameObject: Codable {
    let en: String
}

struct Relationship: Codable {
    let id: String
    let type: String
    let attributes: RelationshipAttributes?
}

struct RelationshipAttributes: Codable {
    let name: String?
    let fileName: String?
}

struct MangaDexChapter: Codable {
    let id: String
    let attributes: ChapterAttributes
    
    func toChapter() -> Chapter {
        let formatter = ISO8601DateFormatter()
        let publishDate = formatter.date(from: attributes.publishAt) ?? Date()
        
        return Chapter(
            id: id,
            number: attributes.chapter,
            title: attributes.title,
            pages: [],
            publishDate: publishDate,
            language: attributes.translatedLanguage
        )
    }
}

struct ChapterAttributes: Codable {
    let chapter: Double
    let title: String?
    let publishAt: String
    let translatedLanguage: String
}

struct ChapterPagesResponse: Codable {
    let baseUrl: String
    let chapter: ChapterData
}

struct ChapterData: Codable {
    let hash: String
    let data: [String]
    let dataSaver: [String]
}
