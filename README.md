# MangaReader iOS App

A native iOS manga reader application built with SwiftUI that integrates with Torbox for file storage/streaming and MangaDex for manga metadata and discovery.

## Features

### Authentication & Settings
- Secure API key storage using iOS Keychain
- Torbox API key management
- Optional MangaDex authentication
- Secure credential management with SwiftUI SecureField

### Manga Discovery & Metadata
- MangaDex API v5 integration for manga browsing and search
- Search functionality with filters (genre, status, rating)
- Fetch manga details including title, cover art, description, authors, tags, and chapter list
- Display seasonal/popular manga on home screen
- Fuzzy matching algorithm to match manga titles with Torbox files

### File Management via Torbox
- Connect to Torbox API using stored API key
- Query available torrents/files from user's Torbox account
- Match manga titles to corresponding Torbox files
- Support torrent management: list torrents, get torrent info, download status
- WebDAV integration for direct file streaming
- Cache file URLs and metadata for offline access

### Reading Experience
- Custom manga reader view with SwiftUI
- Page-by-page navigation with swipe gestures
- Support for both vertical scrolling and horizontal page-flip modes
- Zoom and pan functionality using SwiftUI gestures
- Chapter download for offline reading
- Reading progress tracking (save last read chapter and page)
- Bookmark functionality

## Architecture

### Swift Packages & Dependencies
- **MangaDexLib**: For MangaDex API integration
- **Alamofire**: For HTTP requests (via URLSession)
- **Kingfisher**: For async image loading and caching
- **SwiftUI**: Modern declarative UI framework

### Project Structure
```
MangaReader/
├── MangaReader/
│   ├── Models/
│   │   └── MangaModels.swift          # Data models
│   ├── Services/
│   │   ├── MangaDexService.swift      # MangaDex API integration
│   │   └── TorboxService.swift       # Torbox API integration
│   ├── Views/
│   │   ├── MainTabView.swift         # Main navigation
│   │   ├── BrowseView.swift          # Manga discovery
│   │   ├── LibraryView.swift         # User's library
│   │   ├── MangaDetailView.swift     # Manga details
│   │   ├── ReaderView.swift          # Reading experience
│   │   └── SettingsView.swift        # App settings
│   ├── Utils/
│   │   ├── KeychainManager.swift     # Secure storage
│   │   └── UserDefaultsManager.swift # App preferences
│   ├── Info.plist
│   ├── SceneDelegate.swift
│   └── MangaReaderApp.swift          # App entry point
├── Package.swift                      # Swift Package Manager
└── README.md
```

### API Endpoints

#### Torbox API
- `GET /api/v1/user/profile` - User authentication
- `GET /api/v1/torrents` - List all torrents
- `GET /api/v1/torrents/{id}` - Get torrent details
- `POST /api/v1/torrents/createTorrent` - Add new torrent

#### MangaDex API
- `GET /manga` - Search manga
- `GET /manga/{id}/feed` - Get chapter list
- `GET /at-home/server/{chapterId}` - Get chapter pages

## Setup

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0 or later deployment target
- Torbox API key (get from https://api.torbox.app)
- Optional: MangaDex API key

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd MangaReader
```

2. Open the project in Xcode:
```bash
open Package.swift
```

3. Build the project:
```bash
xcodebuild -scheme MangaReader -configuration Debug build
```

### Configuration

1. Run the app on a simulator or device
2. Navigate to Settings tab
3. Enter your Torbox API key
4. (Optional) Enter your MangaDex API key for advanced features
5. Test the connection to verify API keys are valid

## Usage

### Browsing Manga
1. Tap the "Browse" tab
2. Search for manga using the search bar
3. Tap on a manga to view details

### Reading Manga
1. Select a manga from Browse or Library
2. Choose a chapter from the chapter list
3. Use swipe gestures to navigate between pages
4. Tap once to show/hide controls
5. Double-tap to zoom in/out
6. Tap the menu icon to access bookmarks and reading modes

### Library Management
- Favorite manga by tapping the heart icon on manga details
- View reading progress in the Library tab
- Filter by favorites or downloaded chapters

### Torbox Integration
1. Configure your Torbox API key in Settings
2. Browse manga and tap "Torbox Files" to see available files
3. The app automatically matches manga titles with Torbox torrents
4. Download and read chapters directly from Torbox

## Development

### Running Tests
```bash
cd MangaReader
swift test
```

### Code Quality
```bash
swiftlint --strict
swiftformat --lint .
```

### CI/CD
The project uses GitHub Actions for continuous integration:
- Build validation on push/PR
- SwiftLint checks
- SwiftFormat checks
- Code coverage reporting

### Adding Features
- Follow SwiftUI best practices
- Use async/await for network operations
- Implement proper error handling
- Add unit tests for new features
- Update documentation

## API Documentation

### Torbox API
Base URL: `https://api.torbox.app/v1/api`

Documentation: https://api.torbox.app

### MangaDex API
Base URL: `https://api.mangadex.org`

Documentation: https://api.mangadex.org/docs/

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Run linting and formatting checks
6. Submit a pull request

## License

This project is for educational purposes. Please respect the terms of service of the integrated APIs.

## Acknowledgments

- MangaDex for providing the manga database API
- Torbox for providing file storage and streaming services
- SwiftUI and the Apple developer community

## Troubleshooting

### Common Issues

**API Key Authentication Failed**
- Verify your Torbox API key is correct
- Check that the key has not expired
- Ensure you have a stable internet connection

**Images Not Loading**
- Check your network connection
- Verify MangaDex API is accessible
- Try refreshing the manga list

**Chapter Download Failed**
- Ensure Torbox API key is configured
- Check that the torrent has completed downloading
- Verify the file format is supported

## Future Enhancements

- [ ] Offline reading mode with full chapter caching
- [ ] Support for multiple manga sources
- [ ] Advanced search filters
- [ ] Reading statistics and analytics
- [ ] Cloud sync for reading progress
- [ ] Dark mode enhancements
- [ ] Custom reading settings per manga
- [ ] Support for different file formats (CBZ, CBR)
- [ ] Batch download support
- [ ] Reading recommendations based on history

## Support

For issues, questions, or contributions, please open an issue on GitHub.

## Version History

- **1.0.0** - Initial release
  - Basic manga browsing and reading
  - Torbox integration
  - Library management
  - Reading progress tracking
