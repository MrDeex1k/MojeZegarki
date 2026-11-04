import SwiftUI

struct WearView: View {
    let store: CollectionStore
    var watch: Timepiece?
    var session: WearHistorySession?
    var presentsEditor = true
    @State private var localSession = WearHistorySession()

    var body: some View {
        WearHistoryView(store: store, watch: watch, session: session ?? localSession, presentsEditor: presentsEditor)
    }
}
