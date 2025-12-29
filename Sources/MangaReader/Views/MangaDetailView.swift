import SwiftUI

struct MangaDetailView: View {
    @State private var manga: Manga
    @State private var isLoading = false
    @State private var selectedChapter: Chapter?
    @State private var showTorboxFiles = false
    @State private var torboxFiles: [TorboxFile] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isFavorite = false
    
    init(manga: Manga) {
        _manga = State(initialValue: manga)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                            .aspectRatio(contentMode: .fit)
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
                .frame(maxHeight: 400)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(manga.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            isFavorite.toggle()
                            var updatedManga = manga
                            updatedManga.isFavorite = isFavorite
                            manga = updatedManga
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(isFavorite ? .red : .gray)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Label(manga.status.capitalized, systemImage: "info.circle")
                        
                        if !manga.authors.isEmpty {
                            Label(manga.authors[0], systemImage: "person")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text(manga.description)
                        .font(.body)
                    
                    if !manga.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(manga.tags.prefix(10), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Chapters")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            loadTorboxFiles()
                            showTorboxFiles = true
                        }) {
                            Label("Torbox Files", systemImage: "externaldrive")
                                .font(.caption)
                        }
                    }
                    
                    if isLoading {
                        ProgressView("Loading chapters...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if manga.chapters.isEmpty {
                        Text("No chapters available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(manga.chapters.reversed()) { chapter in
                                ChapterRow(chapter: chapter, mangaId: manga.id) {
                                    selectedChapter = chapter
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedChapter) { chapter in
            ReaderView(chapter: chapter, mangaTitle: manga.title, mangaId: manga.id)
        }
        .sheet(isPresented: $showTorboxFiles) {
            TorboxFilesSheet(files: torboxFiles, mangaTitle: manga.title)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadMangaDetails()
        }
    }
    
    private func loadMangaDetails() {
        isLoading = true
        Task {
            do {
                let detailedManga = try await MangaDexService.shared.getMangaDetails(id: manga.id)
                manga = detailedManga
                
                if let progress = UserDefaultsManager.shared.getReadingProgress(
                    mangaId: manga.id,
                    chapterId: manga.chapters.first?.id ?? ""
                ) {
                    isFavorite = false
                }
            } catch {
                errorMessage = "Failed to load manga details: \(error.localizedDescription)"
                showError = true
            }
            isLoading = false
        }
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

struct ChapterRow: View {
    let chapter: Chapter
    let mangaId: String
    let onTap: () -> Void
    @State private var progress: ReadingProgress?
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = chapter.title {
                        Text("Chapter \(Int(chapter.number)): \(title)")
                            .font(.headline)
                    } else {
                        Text("Chapter \(Int(chapter.number))")
                            .font(.headline)
                    }
                    
                    Text(formatDate(chapter.publishDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if chapter.isDownloaded {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if let progress = progress {
                    VStack(spacing: 2) {
                        ProgressView(value: Double(progress.lastPageRead), total: Double(progress.totalPages))
                            .frame(width: 80)
                        Text("\(progress.lastPageRead)/\(progress.totalPages)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadProgress()
        }
    }
    
    private func loadProgress() {
        progress = UserDefaultsManager.shared.getReadingProgress(
            mangaId: mangaId,
            chapterId: chapter.id
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TorboxFilesSheet: View {
    @Environment(\.dismiss) var dismiss
    let files: [TorboxFile]
    let mangaTitle: String
    
    var body: some View {
        NavigationView {
            List {
                if files.isEmpty {
                    Text("No Torbox files found for \(mangaTitle)")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowInsets(EdgeInsets())
                } else {
                    ForEach(files) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.headline)
                            Text("Size: \(formatBytes(file.size))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Status: \(file.status)")
                                .font(.caption)
                                .foregroundColor(file.status == "completed" ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Torbox Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
