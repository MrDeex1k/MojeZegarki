import SwiftUI

struct WearView: View {
    let store: CollectionStore
    var watch: Timepiece?
    @State private var filterID: UUID?

    var body: some View {
        WearHistoryView(store: store, watch: watch, filterID: $filterID)
    }
}
