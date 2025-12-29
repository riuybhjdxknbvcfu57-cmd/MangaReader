import SwiftUI

struct MangaDetailView: View {
    @State private var manga: Manga
    @State private var isLoading = true
    @State private var selectedChapter: Chapter?
    @State private var showTorboxFiles = false
    @State private var torboxFiles: [TorboxFile] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isFavorite = false
    @State private var coverImage: Image?
    
    init(manga: Manga) {
        _manga = State(initialValue: manga)
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    contentSection
                }
            }
            
            if isLoading {
                LoadingOverlay()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { loadTorboxFiles(); showTorboxFiles = true }) {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { isFavorite.toggle() }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : .white)
                    }
                }
            }
        }
        .sheet(item: $selectedChapter) { chapter in
            ReaderView(chapter: chapter, mangaTitle: manga.title, mangaId: manga.id)
        }
        .sheet(isPresented: $showTorboxFiles) {
            TorboxFilesSheet(files: torboxFiles, mangaTitle: manga.title)
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
    
    private var backgroundGradient: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: manga.coverArt) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 50)
                        .opacity(0.4)
                }
            }
            .ignoresSafeArea()
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
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
            .frame(width: 180, height: 260)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(manga.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !manga.authors.isEmpty {
                    Text(manga.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 16) {
                    StatusBadge(text: manga.status.capitalized, color: statusColor)
                    StatusBadge(text: "\(manga.chapters.count) Chapters", color: .blue)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 24) {
            if !manga.tags.isEmpty {
                tagsSection
            }
            
            if !manga.description.isEmpty {
                descriptionSection
            }
            
            chaptersSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .padding(.top, 16)
    }
    
    private var tagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manga.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(manga.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(6)
        }
    }
    
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(manga.chapters.count) available")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            if manga.chapters.isEmpty && !isLoading {
                Text("No chapters available")
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(manga.chapters.reversed().prefix(50)) { chapter in
                        ChapterRow(chapter: chapter, mangaId: manga.id) {
                            selectedChapter = chapter
                        }
                    }
                }
            }
        }
    }
    
    private func loadMangaDetails() async {
        isLoading = true
        do {
            let detailedManga = try await MangaDexService.shared.getMangaDetails(id: manga.id)
            manga = detailedManga
        } catch {
            errorMessage = "Failed to load manga details: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
    
    private func loadTorboxFiles() {
        Task {
            do {
                torboxFiles = try await TorboxService.shared.searchMangaFiles(mangaTitle: manga.title)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load Torbox files: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
    }
}

struct ChapterRow: View {
    let chapter: Chapter
    let mangaId: String
    let onTap: () -> Void
    @State private var progress: ReadingProgress?
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ch. \(Int(chapter.number))")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let title = chapter.title, !title.isEmpty {
                            Text("- \(title)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    Text(formatDate(chapter.publishDate))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                if let progress = progress {
                    CircularProgress(value: Double(progress.lastPageRead) / Double(progress.totalPages))
                        .frame(width: 24, height: 24)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            progress = UserDefaultsManager.shared.getReadingProgress(mangaId: mangaId, chapterId: chapter.id)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CircularProgress: View {
    let value: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: value)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct TorboxFilesSheet: View {
    @Environment(\.dismiss) var dismiss
    let files: [TorboxFile]
    let mangaTitle: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if files.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Torbox files found")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("for \"\(mangaTitle)\"")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(files) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text(formatBytes(file.size))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text(file.status)
                                    .font(.caption)
                                    .foregroundColor(file.status == "completed" ? .green : .orange)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Torbox Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
