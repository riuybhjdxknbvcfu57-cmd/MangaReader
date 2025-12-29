import SwiftUI

struct ReaderView: View {
    let chapter: Chapter
    let mangaTitle: String
    let mangaId: String
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var settings = UserDefaultsManager.shared
    
    @State private var pages: [URL] = []
    @State private var currentPageIndex = 0
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = false
    @State private var showBookmarkSheet = false
    @State private var bookmarkNote = ""
    @State private var doubleTapToZoom = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading pages...")
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            } else if pages.isEmpty {
                Text("No pages available")
                    .foregroundColor(.white)
            } else {
                GeometryReader { geometry in
                    ZStack {
                        if settings.readingMode == .vertical {
                            VerticalReaderView(
                                pages: pages,
                                currentPageIndex: $currentPageIndex,
                                onPageChange: saveProgress
                            )
                        } else {
                            HorizontalReaderView(
                                pages: pages,
                                currentPageIndex: $currentPageIndex,
                                onPageChange: saveProgress
                            )
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if abs(value.translation.width) > 50 {
                                    if value.translation.width > 0 {
                                        previousPage()
                                    } else {
                                        nextPage()
                                    }
                                }
                            }
                    )
                }
            }
            
            if showControls {
                readerControls
            }
            
            TapGestureView(tapCount: 2) {
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
            .onTapGesture(count: 1) {
                withAnimation {
                    showControls.toggle()
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: showControls ? false : true)
        .sheet(isPresented: $showBookmarkSheet) {
            BookmarkSheet(note: $bookmarkNote) { note in
                addBookmark(note: note)
                showBookmarkSheet = false
            }
        }
        .onAppear {
            loadPages()
        }
    }
    
    private var readerControls: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                if let title = chapter.title {
                    Text("Ch \(Int(chapter.number)): \(title)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("Chapter \(Int(chapter.number))")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Menu {
                    Button("Add Bookmark") {
                        showBookmarkSheet = true
                    }
                    
                    Button("Toggle Reading Mode") {
                        withAnimation {
                            settings.readingMode = settings.readingMode == .vertical ? .horizontal : .vertical
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            
            Spacer()
            
            HStack {
                Button(action: { previousPage() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                Text("\(currentPageIndex + 1) / \(pages.count)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                
                Spacer()
                
                Button(action: { nextPage() }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
        }
    }
    
    private func loadPages() {
        isLoading = true
        Task {
            do {
                if chapter.pages.isEmpty {
                    pages = try await MangaDexService.shared.getChapterPages(chapterId: chapter.id)
                } else {
                    pages = chapter.pages
                }
            } catch {
                print("Failed to load pages: \(error)")
            }
            
            if let progress = UserDefaultsManager.shared.getReadingProgress(
                mangaId: mangaId,
                chapterId: chapter.id
            ) {
                currentPageIndex = progress.lastPageRead
            }
            
            isLoading = false
        }
    }
    
    private func nextPage() {
        if currentPageIndex < pages.count - 1 {
            withAnimation {
                currentPageIndex += 1
            }
            saveProgress()
        }
    }
    
    private func previousPage() {
        if currentPageIndex > 0 {
            withAnimation {
                currentPageIndex -= 1
            }
            saveProgress()
        }
    }
    
    private func saveProgress() {
        let progress = ReadingProgress(
            id: UUID().uuidString,
            mangaId: mangaId,
            chapterId: chapter.id,
            lastPageRead: currentPageIndex,
            totalPages: pages.count,
            lastReadDate: Date(),
            isCompleted: currentPageIndex == pages.count - 1
        )
        UserDefaultsManager.shared.saveReadingProgress(progress)
    }
    
    private func addBookmark(note: String) {
        let bookmark = Bookmark(
            id: UUID().uuidString,
            mangaId: mangaId,
            chapterId: chapter.id,
            pageNumber: currentPageIndex,
            note: note.isEmpty ? nil : note,
            createdAt: Date()
        )
        
        var bookmarks = UserDefaultsManager.shared.getBookmarks(mangaId: mangaId)
        bookmarks.append(bookmark)
        UserDefaultsManager.shared.saveBookmarks(bookmarks, mangaId: mangaId)
    }
}

struct VerticalReaderView: View {
    let pages: [URL]
    @Binding var currentPageIndex: Int
    let onPageChange: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, url in
                    MangaPageImage(url: url, index: index)
                        .onAppear {
                            if index > currentPageIndex {
                                currentPageIndex = index
                                onPageChange()
                            }
                        }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct HorizontalReaderView: View {
    let pages: [URL]
    @Binding var currentPageIndex: Int
    let onPageChange: () -> Void
    @GestureState private var offset: CGFloat = 0
    
    var body: some View {
        TabView(selection: $currentPageIndex) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, url in
                MangaPageImage(url: url, index: index)
                    .tag(index)
                    .onAppear {
                        onPageChange()
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

struct MangaPageImage: View {
    let url: URL
    let index: Int
    @State private var isLoading = true
    
    var body: some View {
        AsyncImage(url: url) { phase in
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
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load page")
                            .font(.caption)
                    }
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .id(index)
    }
}

struct TapGestureView: View {
    let tapCount: Int
    let action: () -> Void
    
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: tapCount)
                    .onEnded { _ in
                        action()
                    }
            )
    }
}

struct BookmarkSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var note: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Bookmark Note")
                } footer: {
                    Text("Leave blank to save without a note")
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(note)
                        dismiss()
                    }
                }
            }
        }
    }
}
