import SwiftUI
import PhotosUI

struct TimepieceEditorView: View {
    let store: CollectionStore
    let watch: Timepiece?
    let wishlistItem: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var draft: TimepieceDraft
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var stagedIDs: Set<UUID> = []
    @State private var importing = false
    @State private var saving = false
    @State private var committed = false
    @State private var errorMessage: String?

    init(store: CollectionStore, watch: Timepiece? = nil, wishlistItem: WishlistItem? = nil) {
        self.store = store
        self.watch = watch
        self.wishlistItem = wishlistItem
        _draft = State(initialValue: watch.map { TimepieceDraft(timepiece: $0) } ?? wishlistItem.map { WishlistDraft(item: $0).purchaseDraft } ?? TimepieceDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $draft.brand).accessibilityIdentifier("editor.brand")
                    TextField("Model", text: $draft.modelName).accessibilityIdentifier("editor.model")
                } header: { Text("Watch") } footer: { Text("Only brand and model are required.") }

                photosSection

                Section("Details") {
                    optionalPicker("Device type", selection: $draft.deviceKind)
                    optionalPicker("Movement", selection: $draft.movementType)
                    NavigationLink {
                        List(WatchCategory.allCases) { category in
                            Toggle(isOn: Binding(get: { draft.categories.contains(category) }, set: { selected in
                                if selected { draft.categories.insert(category) } else { draft.categories.remove(category) }
                            })) { Text(category.title) }
                        }
                        .navigationTitle("Categories")
                    } label: {
                        LabeledContent("Categories", value: draft.categories.isEmpty ? String(localized: "Not specified") : draft.categories.map { String(localized: $0.title) }.sorted().joined(separator: ", "))
                    }
                    TextField("Reference number", text: $draft.referenceNumber).textInputAutocapitalization(.characters)
                    TextField("Serial number", text: $draft.serialNumber).textInputAutocapitalization(.characters)
                    Picker("Status", selection: $draft.status) {
                        ForEach(WatchStatus.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Purchase") {
                    Toggle("Add purchase date", isOn: Binding(get: { draft.purchaseDate != nil }, set: { draft.purchaseDate = $0 ? Date() : nil }))
                    if draft.purchaseDate != nil {
                        DatePicker("Purchase date", selection: Binding(get: { draft.purchaseDate ?? Date() }, set: { draft.purchaseDate = $0 }), displayedComponents: .date)
                    }
                    TextField("Purchase price", text: $draft.price).keyboardType(.decimalPad)
                        .accessibilityIdentifier("editor.price")
                    Picker("Currency", selection: $draft.currencyCode) {
                        Text("Not specified").tag("")
                        ForEach(Locale.commonISOCurrencyCodes.sorted(), id: \.self) { code in
                            Text(verbatim: "\(code) — \(locale.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                        }
                    }
                    TextField("Seller", text: $draft.seller)
                }
                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...8)
                }
            }
            .disabled(saving)
            .navigationTitle(watch == nil ? Text("Add a watch") : Text("Edit watch"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(importing || saving)
                        .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!draft.hasRequiredFields || importing || saving)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .interactiveDismissDisabled(importing || saving)
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                importing = true
                Task { await importPhotos(items) }
            }
        }
        // The whole editor must disappear, not just the form when opening Categories.
        .onDisappear {
            if !committed {
                let abandoned = stagedIDs
                Task { for id in abandoned { try? await store.photoStore.remove(id) } }
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            if !draft.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(draft.photos) { photo in
                            VStack(spacing: 8) {
                                PhotoView(photo: photo, store: store.photoStore)
                                    .frame(width: 130, height: 150).clipShape(RoundedRectangle(cornerRadius: 10))
                                Button {
                                    draft.mainPhotoID = photo.id
                                } label: {
                                    Label(draft.mainPhotoID == photo.id ? "Main photo" : "Set as main", systemImage: draft.mainPhotoID == photo.id ? "star.fill" : "star")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                Button("Remove photo", role: .destructive) { removePhoto(photo) }
                                    .font(.caption).buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            PhotosPicker(selection: $selectedPhotos, matching: .images) {
                Label("Add photos", systemImage: "photo.badge.plus")
            }
            .disabled(importing)
            .accessibilityIdentifier("editor.photos")
            if importing { ProgressView("Importing photos…") }
        }
    }

    private func optionalPicker<T: WatchOption>(_ title: LocalizedStringKey, selection: Binding<T?>) -> some View where T.AllCases: RandomAccessCollection {
        Picker(title, selection: selection) {
            Text("Not specified").tag(Optional<T>.none)
            ForEach(Array(T.allCases)) { Text($0.title).tag(Optional($0)) }
        }
    }

    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos = []; importing = false }
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CollectionError.unreadablePhoto }
                let photo = try await store.photoStore.importPhoto(data)
                stagedIDs.insert(photo.id)
                draft.photos.append(photo)
                if draft.mainPhotoID == nil { draft.mainPhotoID = photo.id }
            } catch { errorMessage = String(localized: "A photo could not be imported. Already imported photos are still available.") }
        }
    }

    private func removePhoto(_ photo: PhotoDraft) {
        draft.photos.removeAll { $0.id == photo.id }
        if draft.mainPhotoID == photo.id { draft.mainPhotoID = draft.photos.first?.id }
    }

    @MainActor private func save() async {
        saving = true
        defer { saving = false }
        let oldIDs = Set((watch?.sortedPhotos.map(\.id) ?? []) + (wishlistItem?.photoID.map { [$0] } ?? []))
        let retainedIDs = Set(draft.photos.map(\.id))
        do {
            try store.save(draft, editing: watch, moving: wishlistItem, locale: locale)
            committed = true
            for id in oldIDs.union(stagedIDs).subtracting(retainedIDs) {
                // Startup reconciliation retries cleanup after a filesystem failure.
                try? await store.photoStore.remove(id)
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
