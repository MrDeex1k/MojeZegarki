import PhotosUI
import SwiftData
import SwiftUI

struct WishlistView: View {
    let store: CollectionStore
    var showCollection: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
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
        items.filter {
            search.trimmed.isEmpty || "\($0.brand) \($0.modelName)".localizedStandardContains(search.trimmed)
        }
    }

    var body: some View {
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
                            let group = visible.filter { $0.priority == priority.rawValue }
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
                                                                Text(item.brand).font(.subheadline).foregroundStyle(
                                                                    .secondary)
                                                                Text(item.modelName).font(.headline).foregroundStyle(
                                                                    .primary)
                                                                if let amount = item.targetPrice.flatMap({
                                                                    Decimal(
                                                                        string: $0,
                                                                        locale: Locale(identifier: "en_US_POSIX"))
                                                                }), let currency = item.currencyCode {
                                                                    Text(amount.formatted(.currency(code: currency)))
                                                                        .font(.subheadline)
                                                                        .foregroundStyle(.secondary)
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
                            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
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

struct WishlistEditorView: View {
    let store: CollectionStore
    let item: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private let initialDraft: WishlistDraft
    @State private var discarding = false
    @State private var draft: WishlistDraft
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewPhoto: PhotoDraft?
    @State private var stagedIDs: Set<UUID> = []
    @State private var importing = false
    @State private var saving = false
    @State private var committed = false
    @State private var error: String?

    init(store: CollectionStore, item: WishlistItem? = nil) {
        self.store = store
        self.item = item
        let initial = item.map { WishlistDraft(item: $0) } ?? WishlistDraft()
        initialDraft = initial
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Watch") {
                    TextField("Brand", text: $draft.brand).accessibilityIdentifier("wish.brand")
                    TextField("Model", text: $draft.modelName).accessibilityIdentifier("wish.model")
                }
                Section("Photo") {
                    if let photo = draft.photo {
                        Button {
                            previewPhoto = photo
                        } label: {
                            PhotoView(photo: photo, store: store.photoStore).frame(height: 190)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View photo")
                        .accessibilityIdentifier("wish.photo.preview")
                        Button("Remove photo", role: .destructive) { draft.photo = nil }
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                    }
                    .disabled(importing)
                    if importing { ProgressView("Importing photos…") }
                }
                Section("Details") {
                    TextField("Link", text: $draft.url).keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Target price", text: $draft.price).keyboardType(.decimalPad)
                    Picker("Currency", selection: $draft.currencyCode) {
                        Text("Not specified").tag("")
                        ForEach(Locale.commonISOCurrencyCodes.sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(WishlistPriority.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Notes") { TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...8) }
            }
            .disabled(saving)
            .navigationTitle(item == nil ? Text("Add to wishlist") : Text("Edit wish"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft != initialDraft { discarding = true } else { dismiss() } }.disabled(
                        importing || saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!draft.purchaseDraft.hasRequiredFields || importing || saving)
                        .accessibilityIdentifier("wish.save")
                }
            }
            .interactiveDismissDisabled(importing || saving || draft != initialDraft)
            .fullScreenCover(item: $previewPhoto) { photo in
                WatchPhotoPreview(photo: photo, store: store.photoStore)
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .appError($error)
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                importing = true
                Task {
                    defer {
                        importing = false
                        selectedPhoto = nil
                    }
                    do {
                        guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                            throw CollectionError.unreadablePhoto
                        }
                        let imported = try await store.photoStore.importPhoto(data.data)
                        stagedIDs.insert(imported.id)
                        draft.photo = imported
                    } catch { self.error = String(localized: "This photo could not be read. Choose another image.") }
                }
            }
        }
        .onDisappear {
            // A full-screen preview also hides the editor; keep any unsaved imported photo alive.
            if !committed && previewPhoto == nil {
                let abandoned = stagedIDs
                Task { for id in abandoned { try? await store.photoStore.remove(id) } }
            }
        }
    }

    @MainActor private func save() async {
        saving = true
        defer { saving = false }
        let oldID = item?.photoID
        do {
            try store.saveWish(draft, editing: item, locale: locale)
            committed = true
            var discarded = stagedIDs
            if let oldID { discarded.insert(oldID) }
            if let retained = draft.photo?.id { discarded.remove(retained) }
            for id in discarded { try? await store.photoStore.remove(id) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
