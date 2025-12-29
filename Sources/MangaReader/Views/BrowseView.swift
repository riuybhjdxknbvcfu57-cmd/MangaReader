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
    @State private var isSearching = false
    @State private var searchResults: [Manga] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        if !searchText.isEmpty {
                            searchResultsSection
                        } else {
                            if let featured = featuredManga {
                                HeroBanner(manga: featured)
                            }
                            
                            MangaRowSection(title: "🔥 Popular", manga: $popularManga, loadMore: loadMorePopular)
                            
                            MangaRowSection(title: "📖 Recently Updated", manga: $recentManga, loadMore: loadMoreRecent)
                            
                            ForEach($genreRows) { $row in
                                GenreRowSection(row: $row)
                            }
                        }
                        
                        Spacer().frame(height: 80)
                    }
                }
                .refreshable {
                    await loadInitialData()
                }
                
                if isLoading && popularManga.isEmpty {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search manga...")
            .onChange(of: searchText) { newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
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
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .padding(.top, 40)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No results for \"\(searchText)\"")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                Text("Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(searchResults) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaCard(manga: manga)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // Debounce
            if searchText == query {
                searchResults = try await MangaDexService.shared.searchManga(query: query)
            }
        } catch {}
        isSearching = false
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
            
            let genreTags = tagsResult.filter { $0.group == "genre" }.prefix(6)
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
                .frame(height: 380)
                .clipped()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("FEATURED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(manga.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if !manga.description.isEmpty {
                        Text(manga.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(manga.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white.opacity(0.9))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
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
                .font(.title3)
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
                .font(.title3)
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
                            .tint(.white)
                            .frame(width: 120, height: 180)
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
            } catch {}
            row.isLoading = false
        }
    }
}

struct MangaCard: View {
    let manga: Manga
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: manga.coverArt) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        )
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(width: 120, height: 170)
            .cornerRadius(8)
            .clipped()
            
            Text(manga.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}
