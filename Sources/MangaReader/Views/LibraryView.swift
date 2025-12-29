import SwiftUI

struct LibraryView: View {
    @StateObject private var settings = UserDefaultsManager.shared
    @State private var libraryManga: [Manga] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var torboxTorrents: [Torrent] = []
    @State private var isLoadingTorrents = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("", selection: $selectedTab) {
                        Text("Favorites").tag(0)
                        Text("Downloads").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if selectedTab == 0 {
                        favoritesTab
                    } else {
                        downloadsTab
                    }
                }
            }
            .navigationTitle("Library")
        }
        .task {
            await loadLibrary()
        }
        .onReceive(settings.$libraryMangaIds) { _ in
            Task { await loadLibrary() }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                Task { await loadTorboxTorrents() }
            }
        }
    }
    
    private var favoritesTab: some View {
        Group {
            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if libraryManga.isEmpty {
                emptyStateView
            } else {
                mangaGridView
            }
        }
    }
    
    private var downloadsTab: some View {
        Group {
            if isLoadingTorrents {
                Spacer()
                ProgressView("Loading Torbox...").tint(.white).foregroundColor(.white)
                Spacer()
            } else if !TorboxService.shared.hasApiKey() {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Torbox API Key Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Add your API key in Settings to see downloads")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if torboxTorrents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Downloads")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Search for manga and add torrents to Torbox")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                torrentListView
            }
        }
    }
    
    private var torrentListView: some View {
        List(torboxTorrents) { torrent in
            NavigationLink(destination: TorrentFilesView(torrent: torrent)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(torrent.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack {
                        Text(formatBytes(torrent.size))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if torrent.progress >= 1.0 {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("\(Int(torrent.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if torrent.progress < 1.0 {
                        ProgressView(value: torrent.progress)
                            .tint(.blue)
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTorboxTorrents()
        }
    }
    
    private func loadLibrary() async {
        guard !settings.libraryMangaIds.isEmpty else {
            libraryManga = []
            return
        }
        
        isLoading = true
        var loadedManga: [Manga] = []
        
        for mangaId in settings.libraryMangaIds {
            do {
                let manga = try await MangaDexService.shared.getMangaDetails(id: mangaId)
                loadedManga.append(manga)
            } catch {}
        }
        
        libraryManga = loadedManga
        isLoading = false
    }
    
    private func loadTorboxTorrents() async {
        guard TorboxService.shared.hasApiKey() else { return }
        
        isLoadingTorrents = true
        do {
            torboxTorrents = try await TorboxService.shared.getTorrents()
        } catch {}
        isLoadingTorrents = false
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Favorites Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tap the heart icon on manga to add favorites")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mangaGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(libraryManga) { manga in
                    NavigationLink(destination: MangaDetailView(manga: manga)) {
                        LibraryMangaCard(manga: manga)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Torrent Files View

struct TorrentFilesView: View {
    let torrent: Torrent
    @State private var downloadUrl: String?
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if torrent.progress < 1.0 {
                VStack(spacing: 16) {
                    ProgressView(value: torrent.progress)
                        .tint(.blue)
                        .frame(width: 200)
                    
                    Text("Downloading: \(Int(torrent.progress * 100))%")
                        .foregroundColor(.white)
                    
                    Text("Come back when it's complete")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if torrent.files.isEmpty {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Ready to Read")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let url = downloadUrl {
                            Link(destination: URL(string: url)!) {
                                Label("Open in Browser", systemImage: "safari")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        } else {
                            Button("Get Download Link") {
                                Task { await getDownloadLink() }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        if let error = error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                List(torrent.files) { file in
                    HStack {
                        Image(systemName: fileIcon(for: file.name))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(formatBytes(file.size))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(torrent.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getDownloadLink() async {
        isLoading = true
        error = nil
        do {
            if let torrentId = Int(torrent.id) {
                downloadUrl = try await TorboxService.shared.getDownloadLink(torrentId: torrentId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "cbz", "cbr", "zip", "rar":
            return "doc.zipper"
        case "pdf":
            return "doc.richtext"
        case "jpg", "jpeg", "png", "webp":
            return "photo"
        default:
            return "doc"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct LibraryMangaCard: View {
    let manga: Manga
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: manga.coverArt) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(Image(systemName: "book.closed").foregroundColor(.gray))
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView())
                    }
                }
                .frame(height: 160)
                .cornerRadius(12)
                .clipped()
                
                if UserDefaultsManager.shared.isFavorite(mangaId: manga.id) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
            
            Text(manga.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }
}
