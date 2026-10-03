import SwiftUI

struct RootView: View {
    let store: CollectionStore
    let lock: AppLock

    @State private var selectedTab = 0
    @State private var revealCollection: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionView(store: store, revealRequest: revealCollection)
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }.tag(0)
            NavigationStack {
                WearView(store: store)
            }
            .tabItem { Label("Wearing", systemImage: "calendar") }.tag(1)
            WishlistView(
                store: store,
                showCollection: {
                    revealCollection = UUID()
                    selectedTab = 0
                }
            )
            .tabItem { Label("Wishlist", systemImage: "heart") }.tag(2)
            SettingsView(lock: lock)
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
        }
    }
}

#Preview("Collection — English") {
    if let store = try? CollectionStore(inMemory: true) {
        RootView(store: store, lock: AppLock()).modelContainer(store.container).environment(
            \.locale, Locale(identifier: "en"))
    }
}

#Preview("Kolekcja — Polski") {
    if let store = try? CollectionStore(inMemory: true) {
        RootView(store: store, lock: AppLock()).modelContainer(store.container).environment(
            \.locale, Locale(identifier: "pl"))
    }
}
