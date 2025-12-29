import SwiftUI

struct LibraryView: View {
    @StateObject private var settings = UserDefaultsManager.shared
    @State private var libraryManga: [Manga] = []
    @State private var showFavoritesOnly = false
    @State private var showDownloadedOnly = false
    
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
            ZStack {
                Color.black.ignoresSafeArea()
                
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
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Browse and add manga to your library")
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
                ForEach(filteredManga) { manga in
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
                
                if manga.isFavorite {
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

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
    }
}
