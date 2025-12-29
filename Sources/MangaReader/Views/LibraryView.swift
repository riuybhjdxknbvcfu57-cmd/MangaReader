import SwiftUI

struct LibraryView: View {
    @StateObject private var settings = UserDefaultsManager.shared
    @State private var libraryManga: [Manga] = []
    @State private var showFavoritesOnly = false
    @State private var showDownloadedOnly = false
    @State private var isEmpty = true
    
    var filteredManga: [Manga] {
        var result = libraryManga
        
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        
        if showDownloadedOnly {
            result = result.filter { manga in
                manga.chapters.contains { $0.isDownloaded }
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredManga.isEmpty {
                    emptyStateView
                } else {
                    mangaGridView
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Favorites Only", isOn: $showFavoritesOnly)
                        Toggle("Downloaded Only", isOn: $showDownloadedOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Browse and add manga to your library")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            NavigationLink("Browse Manga") {
                BrowseView()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var mangaGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredManga) { manga in
                    NavigationLink(destination: MangaDetailView(manga: manga)) {
                        LibraryMangaGridItem(manga: manga)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct LibraryMangaGridItem: View {
    let manga: Manga
    @StateObject private var settings = UserDefaultsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
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
                
                if manga.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.headline)
                    .lineLimit(2)
                
                let progressText = getProgressText()
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    private func getProgressText() -> String {
        guard let progress = UserDefaultsManager.shared.getReadingProgress(
            mangaId: manga.id,
            chapterId: manga.chapters.first?.id ?? ""
        ) else {
            return "\(manga.chapters.count) chapters"
        }
        
        return "Last read: Ch \(Int(progress.chapterId.split(separator: "-").last ?? "") ?? 0)"
    }
}

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
    }
}
