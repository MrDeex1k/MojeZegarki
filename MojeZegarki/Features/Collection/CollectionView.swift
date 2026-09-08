import SwiftUI
import SwiftData

struct CollectionView: View {
    let store: CollectionStore
    @Query(sort: \Timepiece.createdAt, order: .reverse) private var watches: [Timepiece]
    @State private var search = ""
    @State private var archive = false
    @State private var adding = false

    private var visible: [Timepiece] {
        watches.filter {
            ($0.status != .owned) == archive &&
            (search.trimmed.isEmpty || "\($0.brand) \($0.modelName)".localizedStandardContains(search.trimmed))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Collection filter", selection: $archive) {
                    Text("In collection").tag(false)
                    Text("Archive").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityIdentifier("collection.filter")

                if visible.isEmpty {
                    if !search.trimmed.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else if archive {
                        ContentUnavailableView("Archive is empty", systemImage: "archivebox", description: Text("Sold and destroyed watches stay here with their photos and history."))
                    } else {
                        ContentUnavailableView {
                            Label("Your collection starts here", systemImage: "watch.analog")
                        } description: {
                            Text("Add your first watch and keep its story in one place.")
                        } actions: {
                            Button("Add a watch", systemImage: "plus") { adding = true }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("collection.addFirst")
                        }
                    }
                } else {
                    List(visible) { watch in
                      HStack {
                        NavigationLink(value: WatchRoute(id: watch.id)) {
                            HStack(spacing: 16) {
                                PhotoView(photo: watch.mainPhoto.map { PhotoDraft(id: $0.id, filename: $0.filename) }, store: store.photoStore)
                                    .frame(width: 86, height: 104)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(watch.brand).font(.subheadline).foregroundStyle(.secondary)
                                    Text(watch.modelName).font(.headline)
                                    if archive { Text(watch.status.title).font(.caption).foregroundStyle(.secondary) }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .accessibilityIdentifier("watch.\(watch.id.uuidString)")
                        if watch.status == .owned { WearTodayButton(watch: watch, store: store, compact: true) }
                      }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Collection")
            .searchable(text: $search, prompt: "Search brand or model")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add a watch", systemImage: "plus") { adding = true }
                        .accessibilityIdentifier("collection.add")
                }
            }
            .sheet(isPresented: $adding) { TimepieceEditorView(store: store) }
            .navigationDestination(for: WatchRoute.self) { route in
                if let watch = watches.first(where: { $0.id == route.id }) {
                    TimepieceDetailView(watch: watch, store: store)
                }
            }
        }
    }
}

private struct WatchRoute: Hashable { let id: UUID }
