import Foundation
import CryptoKit

class TorboxService: ObservableObject {
    static let shared = TorboxService()
    
    private let baseURL = "https://api.torbox.app/v1/api"
    private var apiKey: String?
    
    private init() {}
    
    func setApiKey(_ key: String) {
        self.apiKey = key
    }
    
    func getUserProfile() async throws -> UserProfile {
        try await makeRequest(endpoint: "/user/profile", method: "GET")
    }
    
    func getTorrents() async throws -> [Torrent] {
        let response: TorrentListResponse = try await makeRequest(endpoint: "/torrents", method: "GET")
        return response.data.map { $0.toTorrent() }
    }
    
    func getTorrentDetails(id: String) async throws -> Torrent {
        let response: TorrentDetailResponse = try await makeRequest(endpoint: "/torrents/\(id)", method: "GET")
        return response.data.toTorrent()
    }
    
    func createTorrent(magnetLink: String, name: String? = nil) async throws -> Torrent {
        var parameters: [String: Any] = ["magnet": magnetLink]
        if let name = name {
            parameters["name"] = name
        }
        
        let response: TorrentDetailResponse = try await makeRequest(endpoint: "/torrents/createTorrent", method: "POST", parameters: parameters)
        return response.data.toTorrent()
    }
    
    func deleteTorrent(id: String) async throws -> Bool {
        let _: EmptyResponse = try await makeRequest(endpoint: "/torrents/\(id)", method: "DELETE")
        return true
    }
    
    func searchMangaFiles(mangaTitle: String) async throws -> [TorboxFile] {
        let torrents = try await getTorrents()
        
        return torrents.compactMap { torrent -> TorboxFile? in
            if isMangaMatch(torrentName: torrent.name, mangaTitle: mangaTitle) {
                return TorboxFile(
                    id: torrent.id,
                    name: torrent.name,
                    size: torrent.size,
                    downloadUrl: URL(string: "webdav://\(torrent.id)")!,
                    torrentHash: torrent.hash,
                    createdAt: torrent.createdAt,
                    status: torrent.status
                )
            }
            return nil
        }
    }
    
    func getWebDAVUrl(for fileId: String) async throws -> URL {
        let torrent = try await getTorrentDetails(id: fileId)
        
        guard let webDavLink = torrent.webDavLink else {
            throw NSError(domain: "TorboxService", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebDAV link not available"])
        }
        
        return URL(string: webDavLink)!
    }
    
    private func isMangaMatch(torrentName: String, mangaTitle: String) -> Bool {
        let cleanTorrentName = torrentName.lowercased()
            .replacingOccurrences(of: "[\\[\\](){}]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "vol\\.", with: "", options: .regularExpression)
            .replacingOccurrences(of: "ch\\.", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanMangaTitle = mangaTitle.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let words = cleanMangaTitle.components(separatedBy: " ").filter { !$0.isEmpty }
        
        let matchCount = words.filter { cleanTorrentName.contains($0) }.count
        
        let threshold = Double(words.count) * 0.6
        
        return Double(matchCount) >= threshold
    }
    
    private func makeRequest<T: Decodable>(endpoint: String, method: String, parameters: [String: Any]? = nil) async throws -> T {
        guard let apiKey = apiKey else {
            throw NSError(domain: "TorboxService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
        }
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(TorboxErrorResponse.self, from: data) {
                throw NSError(domain: "TorboxService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.detail])
            }
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let username: String
    let premium: Bool
}

struct TorrentListResponse: Codable {
    let data: [TorrentDTO]
    let success: Bool
}

struct TorrentDetailResponse: Codable {
    let data: TorrentDTO
    let success: Bool
}

struct EmptyResponse: Codable {
    let success: Bool
}

struct TorrentDTO: Codable {
    let id: String
    let name: String
    let hash: String
    let size: Int64
    let progress: Double
    let download_speed: Int64
    let upload_speed: Int64
    let state: String
    let created_at: String
    let files: [TorrentFileDTO]?
    let webdav: String?
    
    func toTorrent() -> Torrent {
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: created_at) ?? Date()
        
        let torrentFiles = files?.map { file -> TorrentFile in
            TorrentFile(
                id: file.id,
                name: file.name,
                size: file.size,
                path: file.path
            )
        } ?? []
        
        return Torrent(
            id: id,
            name: name,
            hash: hash,
            size: size,
            progress: progress,
            downloadSpeed: download_speed,
            uploadSpeed: upload_speed,
            status: state,
            createdAt: createdAt,
            files: torrentFiles
        )
    }
}

struct TorrentFileDTO: Codable {
    let id: String
    let name: String
    let size: Int64
    let path: String
}

struct TorboxErrorResponse: Codable {
    let detail: String
}
