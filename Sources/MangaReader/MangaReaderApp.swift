import SwiftUI

@main
struct MangaReaderApp: App {
    @StateObject private var settings = UserDefaultsManager.shared
    
    init() {
        // Load Torbox API key from keychain on app launch
        loadTorboxApiKey()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
        }
    }
    
    private func loadTorboxApiKey() {
        do {
            let apiKey = try KeychainManager.shared.get(forKey: "torbox_api_key")
            TorboxService.shared.setApiKey(apiKey)
        } catch {
            // No API key saved yet, that's fine
        }
    }
}
