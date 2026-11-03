import SwiftData
import SwiftUI

struct CollectionView: View {
    let store: CollectionStore
    var revealRequest: UUID?
    @State private var selection: WatchRoute?
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @Environment(\.horizontalSizeClass) private var widthClass
    @ScaledMetric(relativeTo: .subheadline) private var brandFontSize = 18.75
    @Query(sort: \Timepiece.createdAt, order: .reverse) private var watches: [Timepiece]
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var search = ""
    @State private var archive = false
    @State private var adding: TimepieceEditorSession?

    private var visible: [Timepiece] {
        let term = search.trimmed
        return watches.filter {
            ($0.status != .owned) == archive
                && (term.isEmpty || "\($0.brand) \($0.modelName)".localizedStandardContains(term))
        }
    }

    var body: some View {
        let visible = visible
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
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
                        ContentUnavailableView(
                            "Archive is empty", systemImage: "archivebox",
                            description: Text("Sold and destroyed watches stay here with their photos and history."))
                    } else {
                        ContentUnavailableView {
                            Label("Your collection starts here", systemImage: "watch.analog")
                        } description: {
                            Text("Add your first watch and keep its story in one place.")
                        } actions: {
                            Button("Add a watch", systemImage: "plus") { adding = TimepieceEditorSession(store: store) }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("collection.addFirst")
                        }
                    }
                } else {
                    TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { timeline in
                        TodayWearScope(day: WearDay(timeline.date).key) { loggedIDs in
                            List(visible) { watch in
                                HStack {
                                    Button {
                                        selection = WatchRoute(id: watch.id)
                                        compactColumn = .detail
                                    } label: {
                                        (typeSize.isAccessibilitySize
                                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                            : AnyLayout(HStackLayout(spacing: 16))) {
                                                PhotoView(
                                                    photo: watch.mainPhoto.map {
                                                        PhotoDraft(id: $0.id, filename: $0.filename)
                                                    }, store: store.photoStore
                                                )
                                                .frame(
                                                    width: widthClass == .regular ? 60 : 86,
                                                    height: widthClass == .regular ? 72 : 104
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                WatchIdentityLabel(
                                                    brand: watch.brand, model: watch.modelName,
                                                    status: archive ? watch.status : nil,
                                                    brandFont: .system(size: brandFontSize)
                                                )
                                                .padding(.vertical, 6)
                                                Spacer(minLength: 0)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                    .accessibilityHidden(true)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(selection?.id == watch.id ? .isSelected : [])
                                    .accessibilityIdentifier("watch.\(watch.id.uuidString)")
                                    if watch.status == .owned {
                                        WearTodayButton(
                                            watch: watch, store: store, compact: true,
                                            sharedLogged: loggedIDs.contains(watch.id))
                                    }
                                }
                                .listRowBackground(
                                    selection?.id == watch.id && widthClass == .regular
                                        ? Color.accentColor.opacity(0.12) : Color.clear)
                            }
                            .listStyle(.plain)
                        }.id(WearDay(timeline.date).key)
                    }
                }
            }
            .onChange(of: revealRequest) {
                selection = nil
                compactColumn = .sidebar
                archive = false
                search = ""
            }
            .navigationTitle("Collection")
            .searchable(text: $search, prompt: "Search brand or model")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add a watch", systemImage: "plus") { adding = TimepieceEditorSession(store: store) }
                        .accessibilityIdentifier("collection.add")
                }
            }
            .sheet(item: $adding) { TimepieceEditorView(store: store, session: $0) }
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            NavigationStack {
                if let selection, let watch = watches.first(where: { $0.id == selection.id }) {
                    TimepieceDetailView(watch: watch, store: store, onBackToCollection: { compactColumn = .sidebar })
                        .id(watch.id)
                } else {
                    ContentUnavailableView("Select a watch", systemImage: "watch.analog")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: watches.map(\.id)) {
            if let selection, !watches.contains(where: { $0.id == selection.id }) {
                self.selection = nil
                compactColumn = .sidebar
            }
        }
    }
}
