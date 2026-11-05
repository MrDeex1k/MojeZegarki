import SwiftUI

struct RootView: View {
    let store: CollectionStore
    let lock: AppLock

    @State private var selectedTab: AppTab = .collection
    @State private var revealCollection: UUID?

    var body: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selectedTab) {
                Tab("Collection", systemImage: "square.grid.2x2", value: AppTab.collection) { collection }
                Tab("Wearing", systemImage: "calendar", value: AppTab.wear) { wear }
                Tab("Wishlist", systemImage: "heart", value: AppTab.wishlist) { wishlist }
                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) { SettingsView(lock: lock) }
            }
        } else {
            TabView(selection: $selectedTab) {
                collection.tabItem { Label("Collection", systemImage: "square.grid.2x2") }.tag(AppTab.collection)
                wear.tabItem { Label("Wearing", systemImage: "calendar") }.tag(AppTab.wear)
                wishlist.tabItem { Label("Wishlist", systemImage: "heart") }.tag(AppTab.wishlist)
                SettingsView(lock: lock).tabItem { Label("Settings", systemImage: "gearshape") }.tag(AppTab.settings)
            }
        }
    }

    private var collection: some View { CollectionView(store: store, revealRequest: revealCollection) }
    private var wear: some View { NavigationStack { WearView(store: store) } }
    private var wishlist: some View {
        WishlistView(store: store) {
            revealCollection = UUID()
            selectedTab = .collection
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
