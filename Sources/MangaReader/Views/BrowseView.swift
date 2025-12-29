import SwiftUI

struct BrowseView: View {
    @State private var searchText = ""
    @State private var mangaList: [Manga] = []
    @State private var isLoading = false
    @State private var selectedManga: Manga?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var filteredManga: [Manga] {
        if searchText.isEmpty {
            return mangaList
        }
        return mangaList.filter { manga in
            manga.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredManga) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaGridItem(manga: manga)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Browse")
            .searchable(text: $searchText, prompt: "Search manga...")
            .onAppear {
                loadPopularManga()
            }
            .refreshable {
                loadPopularManga()
            }
            .overlay(Group {
                if isLoading {
                    ProgressView("Loading...")
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadPopularManga() {
        isLoading = true
        Task {
            do {
                mangaList = try await MangaDexService.shared.getPopularManga()
            } catch {
                errorMessage = "Failed to load manga: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
    }
}

struct MangaGridItem: View {
    let manga: Manga
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: manga.coverArt) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 250)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let rating = manga.rating {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                    }
                }
                
                if !manga.authors.isEmpty {
                    Text(manga.authors.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}

struct BrowseView_Previews: PreviewProvider {
    static var previews: some View {
        BrowseView()
    }
}
