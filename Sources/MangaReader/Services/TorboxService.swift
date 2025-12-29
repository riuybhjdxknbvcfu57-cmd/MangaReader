import Foundation

class TorboxService: ObservableObject {
    static let shared = TorboxService()
    
    private let baseURL = "https://api.torbox.app/v1/api"
    private var apiKey: String?
    
    private init() {}
    
    func setApiKey(_ key: String) {
        self.apiKey = key
    }
    
    func hasApiKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    func getUserProfile() async throws -> UserProfile {
        try await makeRequest(endpoint: "/user/me", method: "GET")
    }
    
    func getTorrents() async throws -> [Torrent] {
        let response: TorrentListResponse = try await makeRequest(endpoint: "/torrents/mylist", method: "GET")
        return response.data?.map { $0.toTorrent() } ?? []
    }
    
    func searchTorrents(query: String) async throws -> [TorrentSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: TorrentSearchResponse = try await makeRequest(
            endpoint: "/torrents/search?query=\(encodedQuery)",
            method: "GET"
        )
        return response.data ?? []
    }
    
    func addMagnet(magnet: String) async throws -> AddTorrentResponse {
        let boundary = UUID().uuidString
        
        guard let apiKey = apiKey else {
            throw NSError(domain: "TorboxService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
        }
        
        guard let url = URL(string: "\(baseURL)/torrents/createtorrent") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"magnet\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(magnet)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TorboxService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(AddTorrentResponse.self, from: data)
    }
    
    func getDownloadLink(torrentId: Int, fileId: Int? = nil) async throws -> String {
        var endpoint = "/torrents/requestdl?token=\(apiKey ?? "")&torrent_id=\(torrentId)"
        if let fileId = fileId {
            endpoint += "&file_id=\(fileId)"
        }
        
        let response: DownloadLinkResponse = try await makeRequest(endpoint: endpoint, method: "GET")
        return response.data ?? ""
    }
    
    func searchMangaFiles(mangaTitle: String) async throws -> [TorboxFile] {
        let torrents = try await getTorrents()
        
        return torrents.compactMap { torrent -> TorboxFile? in
            if isMangaMatch(torrentName: torrent.name, mangaTitle: mangaTitle) {
                return TorboxFile(
                    id: torrent.id,
                    name: torrent.name,
                    size: torrent.size,
                    downloadUrl: URL(string: "torbox://\(torrent.id)")!,
                    torrentHash: torrent.hash,
                    createdAt: torrent.createdAt,
                    status: torrent.status
                )
            }
            return nil
        }
    }
    
    private func isMangaMatch(torrentName: String, mangaTitle: String) -> Bool {
        let cleanTorrentName = torrentName.lowercased()
            .replacingOccurrences(of: "[\\[\\](){}]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanMangaTitle = mangaTitle.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanTorrentName.contains(cleanMangaTitle) || cleanMangaTitle.split(separator: " ").allSatisfy { cleanTorrentName.contains($0.lowercased()) }
    }
    
    private func makeRequest<T: Decodable>(endpoint: String, method: String, parameters: [String: Any]? = nil) async throws -> T {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw NSError(domain: "TorboxService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not set. Please add your Torbox API key in Settings."])
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
                throw NSError(domain: "TorboxService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.detail ?? errorResponse.error ?? "Unknown error"])
            }
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct UserProfile: Codable {
    let id: Int?
    let email: String?
    let plan: Int?
}

struct TorrentListResponse: Codable {
    let data: [TorrentDTO]?
    let success: Bool?
}

struct TorrentSearchResponse: Codable {
    let data: [TorrentSearchResult]?
    let success: Bool?
}

struct TorrentSearchResult: Codable, Identifiable {
    let id: String?
    let name: String
    let size: Int64?
    let seeders: Int?
    let leechers: Int?
    let magnet: String?
    let hash: String?
    
    var displayId: String { id ?? hash ?? UUID().uuidString }
}

struct AddTorrentResponse: Codable {
    let success: Bool?
    let data: AddTorrentData?
}

struct AddTorrentData: Codable {
    let torrentId: Int?
    let hash: String?
    
    enum CodingKeys: String, CodingKey {
        case torrentId = "torrent_id"
        case hash
    }
}

struct DownloadLinkResponse: Codable {
    let success: Bool?
    let data: String?
}

struct TorrentDTO: Codable {
    let id: Int
    let name: String
    let hash: String?
    let size: Int64?
    let progress: Double?
    let downloadSpeed: Int64?
    let uploadSpeed: Int64?
    let downloadState: String?
    let createdAt: String?
    let files: [TorrentFileDTO]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, hash, size, progress, files
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case downloadState = "download_state"
        case createdAt = "created_at"
    }
    
    func toTorrent() -> Torrent {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: createdAt ?? "") ?? Date()
        
        let torrentFiles = files?.map { file -> TorrentFile in
            TorrentFile(
                id: String(file.id),
                name: file.name ?? "",
                size: file.size ?? 0,
                path: file.name ?? ""
            )
        } ?? []
        
        return Torrent(
            id: String(id),
            name: name,
            hash: hash ?? "",
            size: size ?? 0,
            progress: progress ?? 0,
            downloadSpeed: downloadSpeed ?? 0,
            uploadSpeed: uploadSpeed ?? 0,
            status: downloadState ?? "unknown",
            createdAt: date,
            files: torrentFiles,
            webDavLink: nil
        )
    }
}

struct TorrentFileDTO: Codable {
    let id: Int
    let name: String?
    let size: Int64?
}

struct TorboxErrorResponse: Codable {
    let detail: String?
    let error: String?
}
