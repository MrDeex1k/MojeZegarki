import PhotosUI
import SwiftData
import SwiftUI

struct WishlistView: View {
    let store: CollectionStore
    var showCollection: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editMode: EditMode = .inactive
    @State private var movedName: String?
    @State private var undoMove: CollectionStore.WishMoveUndo?
    @Query(sort: [
        SortDescriptor(\WishlistItem.priority, order: .reverse),
        SortDescriptor(\WishlistItem.position),
        SortDescriptor(\WishlistItem.createdAt, order: .reverse),
    ]) private var items: [WishlistItem]
    @Environment(\.locale) private var locale
    @State private var search = ""
    @State private var adding = false
    @State private var editing: WishlistItem?
    @State private var moving: WishlistItem?
    @State private var deleting: WishlistItem?
    @State private var error: String?

    private var visible: [WishlistItem] {
        let term = search.trimmed
        return items.filter {
            term.isEmpty || "\($0.brand) \($0.modelName)".localizedStandardContains(term)
        }
    }

    var body: some View {
        let visible = visible
        let groups = Dictionary(grouping: visible, by: \.priority)
        NavigationStack {
            Group {
                if visible.isEmpty {
                    if search.trimmed.isEmpty {
                        ContentUnavailableView {
                            Label("Your next watch", systemImage: "heart")
                        } description: {
                            Text("Save a watch you would like to add to your collection.")
                        } actions: {
                            Button("Add to wishlist", systemImage: "plus") { adding = true }.buttonStyle(
                                .borderedProminent)
                        }
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                } else {
                    List {
                        ForEach(WishlistPriority.allCases.reversed()) { priority in
                            let group = groups[priority.rawValue, default: []]
                            if !group.isEmpty {
                                Section {
                                    ForEach(group) { item in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 12) {
                                                Button {
                                                    editing = item
                                                } label: {
                                                    (typeSize.isAccessibilitySize
                                                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                                        : AnyLayout(HStackLayout(spacing: 12))) {
                                                            PhotoView(photo: item.photo, store: store.photoStore)
                                                                .frame(width: 70, height: 88).clipShape(
                                                                    RoundedRectangle(cornerRadius: 10))
                                                            VStack(alignment: .leading, spacing: 4) {
                                                                WatchIdentityLabel(
                                                                    brand: item.brand, model: item.modelName)
                                                                if let amount = item.targetPrice.flatMap({
                                                                    Decimal(
                                                                        string: $0,
                                                                        locale: Locale(identifier: "en_US_POSIX"))
                                                                }), let currency = item.currencyCode {
                                                                    Text(amount.formatted(.currency(code: currency)))
                                                                        .font(.subheadline)
                                                                        .foregroundStyle(Color.supportingText)
                                                                }
                                                                if let priority = WishlistPriority(
                                                                    rawValue: item.priority),
                                                                    priority != .unspecified
                                                                {
                                                                    Text(priority.title).font(.caption).foregroundStyle(
                                                                        .secondary)
                                                                }
                                                            }
                                                        }
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityIdentifier("wish.\(item.id)")
                                                Button("Add to collection", systemImage: "plus.circle.fill") {
                                                    do {
                                                        let name = "\(item.brand) \(item.modelName)"
                                                        undoMove = try store.moveWish(item)
                                                        movedName = name
                                                    } catch { self.error = error.localizedDescription }
                                                }
                                                .buttonStyle(.bordered)
                                                .accessibilityIdentifier("wish.quickMove.\(item.id)")
                                            }
                                            Menu {
                                                Button("Edit", systemImage: "pencil") { editing = item }
                                                Button("Complete details and add", systemImage: "plus.circle") {
                                                    moving = item
                                                }
                                                .accessibilityIdentifier("wish.move")
                                                if let rawURL = item.url, let url = URL(string: rawURL),
                                                    ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                                                {
                                                    Link("Open link", destination: url)
                                                }
                                                Button("Delete", systemImage: "trash", role: .destructive) {
                                                    deleting = item
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle").font(.title2).frame(
                                                    width: 44, height: 44)
                                            }
                                            .buttonStyle(.borderless)
                                            .accessibilityLabel("Watch actions")
                                            .accessibilityIdentifier("wish.actions.\(item.id)")
                                        }
                                        .swipeActions {
                                            Button("Delete", role: .destructive) { deleting = item }
                                            Button("Edit") { editing = item }
                                        }
                                        .moveDisabled(!search.trimmed.isEmpty)
                                    }
                                    .onMove { source, destination in
                                        var reordered = group
                                        reordered.move(fromOffsets: source, toOffset: destination)
                                        do {
                                            try store.reorderWishes(reordered.map(\.id), priority: priority)
                                        } catch { self.error = error.localizedDescription }
                                    }
                                } header: {
                                    Text(priority.title)
                                }
                            }
                        }
                    }
                    .environment(\.editMode, $editMode)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let movedName {
                    VStack(spacing: 8) {
                        Text("Added to collection: \(movedName)").font(.subheadline)
                        (typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())) {
                                Button("Undo") {
                                    do {
                                        if let undoMove { try store.undoWishMove(undoMove) }
                                        self.undoMove = nil
                                        self.movedName = nil
                                    } catch { self.error = error.localizedDescription }
                                }
                                Button("Show collection") {
                                    self.movedName = nil
                                    showCollection()
                                }
                                Spacer()
                                Button("Done") { self.movedName = nil }
                            }
                    }.padding().background(.regularMaterial)
                }
            }
            .navigationTitle("Wishlist")
            .searchable(text: $search, prompt: "Search brand or model")
            .onChange(of: search) { if !search.trimmed.isEmpty { editMode = .inactive } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if items.count > 1 && search.trimmed.isEmpty {
                        Button(editMode.isEditing ? "Done" : "Reorder") {
                            withAnimation(reduceMotion ? nil : .default) {
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                        }
                        .accessibilityIdentifier("wish.reorder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add to wishlist", systemImage: "plus") { adding = true }
                        .accessibilityIdentifier("wish.add")
                }
            }
            .sheet(isPresented: $adding) { WishlistEditorView(store: store) }
            .sheet(item: $editing) { WishlistEditorView(store: store, item: $0) }
            .sheet(item: $moving) { TimepieceEditorView(store: store, wishlistItem: $0) }
            .confirmationDialog(
                "Delete this wish?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let deleting else { return }
                    Task {
                        do { try await store.deleteWish(deleting) } catch { self.error = error.localizedDescription }
                        self.deleting = nil
                    }
                }
            }
            .appError($error)
        }
    }
}
