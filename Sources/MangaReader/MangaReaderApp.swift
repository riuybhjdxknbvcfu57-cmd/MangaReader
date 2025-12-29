import SwiftUI

@main
struct MangaReaderApp: App {
    @StateObject private var settings = UserDefaultsManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
        }
    }
}
