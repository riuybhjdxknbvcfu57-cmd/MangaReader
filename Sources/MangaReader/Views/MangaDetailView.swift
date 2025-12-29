import SwiftUI

struct MangaDetailView: View {
    @State private var manga: Manga
    @State private var isLoading = true
    @State private var selectedChapter: Chapter?
    @State private var showTorboxSearch = false
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var settings = UserDefaultsManager.shared
    
    init(manga: Manga) {
        _manga = State(initialValue: manga)
    }
    
    private var isFavorite: Bool {
        settings.isFavorite(mangaId: manga.id)
    }
    
    private var isInLibrary: Bool {
        settings.isInLibrary(mangaId: manga.id)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dynamic poster background
                AsyncImage(url: manga.coverArt) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blur(radius: 30)
                            .scaleEffect(1.2)
                    }
                }
                .ignoresSafeArea()
                
                // Dark gradient overlay
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.3), location: 0),
                        .init(color: .black.opacity(0.7), location: 0.3),
                        .init(color: .black.opacity(0.95), location: 0.6),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with cover
                        headerSection(geo: geo)
                        
                        // Content
                        contentSection
                    }
                }
                
                if isLoading {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: {
                        settings.addToLibrary(mangaId: manga.id)
                    }) {
                        Image(systemName: isInLibrary ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isInLibrary ? .blue : .white)
                            .font(.title3)
                    }
                    
                    Button(action: {
                        settings.toggleFavorite(mangaId: manga.id)
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : .white)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(item: $selectedChapter) { chapter in
            ReaderView(chapter: chapter, mangaTitle: manga.title, mangaId: manga.id)
        }
        .sheet(isPresented: $showTorboxSearch) {
            TorboxSearchSheet(mangaTitle: manga.title, mangaId: manga.id) {
                // Download started callback
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadMangaDetails()
        }
    }
    
    private func headerSection(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            
            // Cover image
            AsyncImage(url: manga.coverArt) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Image(systemName: "book.closed").font(.largeTitle).foregroundColor(.gray))
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(width: 160, height: 230)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Title and info
            VStack(spacing: 8) {
                Text(manga.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if !manga.authors.isEmpty {
                    Text(manga.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Status badges
                HStack(spacing: 12) {
                    StatusPill(text: manga.status.capitalized, color: statusColor)
                    StatusPill(text: "\(manga.chapters.count) Ch", color: .blue)
                }
                .padding(.top, 4)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                ActionButton(icon: "play.fill", title: "Read", color: .blue) {
                    if let firstChapter = manga.chapters.first {
                        selectedChapter = firstChapter
                    }
                }
                
                ActionButton(icon: "arrow.down.circle", title: "Torbox", color: .orange) {
                    showTorboxSearch = true
                }
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 20)
    }
    
    private var statusColor: Color {
        switch manga.status.lowercased() {
        case "ongoing": return .green
        case "completed": return .blue
        case "hiatus": return .orange
        default: return .gray
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tags
            if !manga.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manga.tags.prefix(8), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white.opacity(0.8))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Synopsis
            if !manga.description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Synopsis")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(manga.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                }
                .padding(.horizontal, 16)
            }
            
            // Chapters
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Chapters")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !manga.chapters.isEmpty {
                        Text("\(manga.chapters.count) available")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                
                if manga.chapters.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No chapters found")
                            .foregroundColor(.gray)
                        Text("Try searching on Torbox")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(manga.chapters.reversed().prefix(100)) { chapter in
                            ChapterCell(chapter: chapter, mangaId: manga.id) {
                                selectedChapter = chapter
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
            
            Spacer().frame(height: 100)
        }
        .padding(.top, 16)
    }
    
    private func loadMangaDetails() async {
        isLoading = true
        do {
            let detailedManga = try await MangaDexService.shared.getMangaDetails(id: manga.id)
            manga = detailedManga
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color)
            .cornerRadius(20)
        }
    }
}

struct ChapterCell: View {
    let chapter: Chapter
    let mangaId: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapter \(Int(chapter.number))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let title = chapter.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(formatDate(chapter.publishDate))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Torbox Search Sheet

struct TorboxSearchSheet: View {
    @Environment(\.dismiss) var dismiss
    let mangaTitle: String
    let mangaId: String
    let onDownloadStarted: () -> Void
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [TorrentSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var isAdding = false
    @State private var addedHashes: Set<String> = []
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search torrents...", text: $searchQuery)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .onSubmit {
                                Task { await search() }
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                    
                    // Results
                    if isSearching {
                        Spacer()
                        ProgressView("Searching Nyaa.si...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else if searchResults.isEmpty && hasSearched {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No results found")
                                .foregroundColor(.white)
                            Text("Try a different search term")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else if searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Search for manga torrents")
                                .foregroundColor(.white)
                            Text("Results will appear here")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List(searchResults, id: \.displayId) { result in
                            TorrentResultRow(
                                result: result,
                                isAdded: addedHashes.contains(result.hash ?? ""),
                                onAdd: { await addTorrent(result) }
                            )
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Torbox Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Search") {
                        Task { await search() }
                    }
                    .foregroundColor(.blue)
                    .disabled(searchQuery.isEmpty || isSearching)
                }
            }
            .alert("Added to Torbox!", isPresented: $showSuccess) {
                Button("OK") { }
            } message: {
                Text("The torrent has been added to your Torbox downloads and saved to your library.")
            }
        }
        .onAppear {
            searchQuery = mangaTitle
            // Auto-search on appear
            Task { await search() }
        }
    }
    
    private func search() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        do {
            searchResults = try await TorboxService.shared.searchTorrents(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSearching = false
    }
    
    private func addTorrent(_ result: TorrentSearchResult) async {
        guard let magnet = result.magnet else { return }
        
        do {
            _ = try await TorboxService.shared.addMagnet(magnet: magnet)
            if let hash = result.hash {
                addedHashes.insert(hash)
            }
            
            // Save manga to library when torrent is added
            await MainActor.run {
                UserDefaultsManager.shared.addToLibrary(mangaId: mangaId)
                UserDefaultsManager.shared.saveTorboxDownload(
                    mangaId: mangaId,
                    torrentHash: result.hash ?? "",
                    torrentName: result.name
                )
                onDownloadStarted()
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add: \(error.localizedDescription)"
            }
        }
    }
}

struct TorrentResultRow: View {
    let result: TorrentSearchResult
    let isAdded: Bool
    let onAdd: () async -> Void
    
    @State private var isAdding = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    if let size = result.size {
                        Label(formatBytes(size), systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let seeders = result.seeders {
                        Label("\(seeders)", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if let leechers = result.leechers {
                        Label("\(leechers)", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isAdding {
                ProgressView()
                    .tint(.white)
            } else {
                Button(action: {
                    isAdding = true
                    Task {
                        await onAdd()
                        isAdding = false
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
