import SwiftUI

struct RootView: View {
    let store: CollectionStore
    let lock: AppLock

    var body: some View {
        TabView {
            CollectionView(store: store)
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }
            NavigationStack {
                WearView(store: store)
            }
            .tabItem { Label("Wearing", systemImage: "calendar") }
            WishlistView(store: store)
            .tabItem { Label("Wishlist", systemImage: "heart") }
            SettingsView(lock: lock)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview("Collection — English") {
    if let store = try? CollectionStore(inMemory: true) {
        RootView(store: store, lock: AppLock()).modelContainer(store.container).environment(\.locale, Locale(identifier: "en"))
    }
}

#Preview("Kolekcja — Polski") {
    if let store = try? CollectionStore(inMemory: true) {
        RootView(store: store, lock: AppLock()).modelContainer(store.container).environment(\.locale, Locale(identifier: "pl"))
    }
}
