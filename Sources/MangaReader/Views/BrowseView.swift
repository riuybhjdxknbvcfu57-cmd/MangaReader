import SwiftUI

struct BrowseView: View {
    @State private var searchText = ""
    @State private var popularManga: [Manga] = []
    @State private var recentManga: [Manga] = []
    @State private var genreRows: [GenreRow] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var featuredManga: Manga?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        if let featured = featuredManga {
                            HeroBanner(manga: featured)
                        }
                        
                        if !searchText.isEmpty {
                            SearchResultsSection(searchText: searchText)
                        } else {
                            MangaRowSection(title: "🔥 Popular Now", manga: $popularManga, loadMore: loadMorePopular)
                            
                            MangaRowSection(title: "📖 Recently Updated", manga: $recentManga, loadMore: loadMoreRecent)
                            
                            ForEach($genreRows) { $row in
                                GenreRowSection(row: $row)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadInitialData()
                }
                
                if isLoading {
                    LoadingOverlay()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search manga...")
        }
        .task {
            await loadInitialData()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadInitialData() async {
        isLoading = true
        do {
            async let popular = MangaDexService.shared.getPopularManga(limit: 20)
            async let recent = MangaDexService.shared.getRecentlyUpdated(limit: 20)
            async let tags = MangaDexService.shared.getTags()
            
            let (popularResult, recentResult, tagsResult) = try await (popular, recent, tags)
            
            popularManga = popularResult
            recentManga = recentResult
            featuredManga = popularResult.first
            
            let genreTags = tagsResult.filter { $0.group == "genre" }.prefix(8)
            genreRows = genreTags.map { GenreRow(tag: $0, manga: [], offset: 0, isLoading: false) }
            
            for i in genreRows.indices {
                let manga = try await MangaDexService.shared.getMangaByTag(tagId: genreRows[i].tag.id, limit: 10)
                genreRows[i].manga = manga
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func loadMorePopular() async {
        do {
            let more = try await MangaDexService.shared.getPopularManga(limit: 20, offset: popularManga.count)
            popularManga.append(contentsOf: more)
        } catch {}
    }
    
    private func loadMoreRecent() async {
        do {
            let more = try await MangaDexService.shared.getRecentlyUpdated(limit: 20, offset: recentManga.count)
            recentManga.append(contentsOf: more)
        } catch {}
    }
}

struct GenreRow: Identifiable {
    let id = UUID()
    let tag: MangaTag
    var manga: [Manga]
    var offset: Int
    var isLoading: Bool
}

struct HeroBanner: View {
    let manga: Manga
    @State private var dominantColor: Color = .purple
    
    var body: some View {
        NavigationLink(destination: MangaDetailView(manga: manga)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: manga.coverArt) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 400)
                .clipped()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("FEATURED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(manga.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(manga.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    
                    HStack {
                        ForEach(manga.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MangaRowSection: View {
    let title: String
    @Binding var manga: [Manga]
    let loadMore: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(manga) { item in
                        NavigationLink(destination: MangaDetailView(manga: item)) {
                            MangaCard(manga: item)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            if item.id == manga.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GenreRowSection: View {
    @Binding var row: GenreRow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(row.tag.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(row.manga) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaCard(manga: manga)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            if manga.id == row.manga.last?.id {
                                loadMoreForGenre()
                            }
                        }
                    }
                    
                    if row.isLoading {
                        ProgressView()
                            .frame(width: 140, height: 200)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func loadMoreForGenre() {
        guard !row.isLoading else { return }
        row.isLoading = true
        Task {
            do {
                let more = try await MangaDexService.shared.getMangaByTag(
                    tagId: row.tag.id,
                    limit: 10,
                    offset: row.manga.count
                )
                row.manga.append(contentsOf: more)
                row.offset = row.manga.count
            } catch {}
            row.isLoading = false
        }
    }
}

struct MangaCard: View {
    let manga: Manga
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: manga.coverArt) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        )
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
            }
            .frame(width: 140, height: 200)
            .cornerRadius(12)
            .clipped()
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text(manga.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
        }
    }
}

struct SearchResultsSection: View {
    let searchText: String
    @State private var results: [Manga] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(results) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaCard(manga: manga)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: searchText) { newValue in
            Task {
                isSearching = true
                do {
                    results = try await MangaDexService.shared.searchManga(query: newValue)
                } catch {}
                isSearching = false
            }
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Loading...")
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .ignoresSafeArea()
    }
}
