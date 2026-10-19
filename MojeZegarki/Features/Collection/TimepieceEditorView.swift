import PhotosUI
import SwiftUI

struct TimepieceEditorView: View {
    let store: CollectionStore
    let watch: Timepiece?
    let wishlistItem: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private let initialDraft: TimepieceDraft
    @State private var discarding = false
    @State private var draft: TimepieceDraft
    @State private var choosingPhotos = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var assets: DraftAssetSession
    @State private var saving = false
    @State private var errorMessage: String?

    init(store: CollectionStore, watch: Timepiece? = nil, wishlistItem: WishlistItem? = nil) {
        self.store = store
        _assets = State(initialValue: DraftAssetSession { try await store.photoStore.remove($0) })
        self.watch = watch
        self.wishlistItem = wishlistItem
        let initial =
            watch.map { TimepieceDraft(timepiece: $0) } ?? wishlistItem.map { WishlistDraft(item: $0).purchaseDraft }
            ?? TimepieceDraft()
        initialDraft = initial
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $draft.brand).accessibilityIdentifier("editor.brand")
                    TextField("Model", text: $draft.modelName).accessibilityIdentifier("editor.model")
                } header: {
                    Text("Watch").foregroundStyle(Color(uiColor: .label))
                } footer: {
                    Text("Only brand and model are required.").foregroundStyle(Color(uiColor: .label))
                }

                photosSection

                Section {
                    optionalPicker("Device type", selection: $draft.deviceKind)
                    optionalPicker("Movement", selection: $draft.movementType)
                    NavigationLink {
                        List(WatchCategory.allCases) { category in
                            Toggle(
                                isOn: Binding(
                                    get: { draft.categories.contains(category) },
                                    set: { selected in
                                        if selected {
                                            draft.categories.insert(category)
                                        } else {
                                            draft.categories.remove(category)
                                        }
                                    })
                            ) { Text(category.title) }
                        }
                        .navigationTitle("Categories")
                    } label: {
                        LabeledContent(
                            "Categories",
                            value: draft.categories.isEmpty
                                ? String(localized: "Not specified")
                                : draft.categories.map { String(localized: $0.title) }.sorted().joined(separator: ", "))
                    }
                    TextField("Reference number", text: $draft.referenceNumber).textInputAutocapitalization(.characters)
                    TextField("Serial number", text: $draft.serialNumber).textInputAutocapitalization(.characters)
                    Picker("Status", selection: $draft.status) {
                        ForEach(WatchStatus.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Details").foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    OptionalDateField(
                        toggleTitle: "Add purchase date", dateTitle: "Purchase date", selection: $draft.purchaseDate)
                    TextField("Purchase price", text: $draft.price).keyboardType(.decimalPad)
                        .accessibilityIdentifier("editor.price")
                    CurrencyPicker(selection: $draft.currencyCode)
                    TextField("Seller", text: $draft.seller)
                } header: {
                    Text("Purchase").foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...8)
                } header: {
                    Text("Notes").foregroundStyle(Color(uiColor: .label))
                }
            }
            .disabled(saving)
            .navigationTitle(watch == nil ? Text("Add a watch") : Text("Edit watch"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft != initialDraft { discarding = true } else { dismiss() } }.tint(
                        Color(uiColor: .label)
                    )
                    .disabled(assets.isImporting || saving)
                    .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!draft.hasRequiredFields || assets.isImporting || saving)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .interactiveDismissDisabled(assets.isImporting || saving || draft != initialDraft)
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($errorMessage)
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                assets.run { await importPhotos(items) }
            }
        }
    }

    private var photosSection: some View {
        Section {
            if !draft.photos.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(draft.photos.enumerated()), id: \.element.id) { index, photo in
                            VStack(spacing: 8) {
                                PhotoView(photo: photo, store: store.photoStore)
                                    .frame(width: 130, height: 150).clipShape(RoundedRectangle(cornerRadius: 10))
                                Button {
                                    draft.mainPhotoID = photo.id
                                } label: {
                                    Label(
                                        draft.mainPhotoID == photo.id ? "Main photo" : "Set as main",
                                        systemImage: draft.mainPhotoID == photo.id ? "star.fill" : "star"
                                    )
                                    .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .frame(minHeight: 44)
                                .accessibilityValue(Text("Photo \(index + 1)"))
                                .accessibilityAddTraits(draft.mainPhotoID == photo.id ? .isSelected : [])
                                Button("Remove photo", role: .destructive) { removePhoto(photo) }
                                    .font(.caption).buttonStyle(.borderless)
                                    .frame(minHeight: 44)
                                    .accessibilityValue(Text("Photo \(index + 1)"))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Button {
                choosingPhotos = true
            } label: {
                Label("Add photos", systemImage: "photo.badge.plus")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
            }
            .photosPicker(
                isPresented: $choosingPhotos, selection: $selectedPhotos, maxSelectionCount: 10, matching: .images
            )
            .disabled(assets.isImporting)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Add photos")
            .accessibilityIdentifier("editor.photos")
            if assets.isImporting {
                ProgressView(value: Double(assets.importedCount), total: Double(max(selectedPhotos.count, 1))) {
                    Text("Importing photos…")
                }
                Button("Stop importing") { assets.stop() }
            }
            Text("Up to 10 photos at a time, 20 MB each.").font(.footnote).foregroundStyle(Color(uiColor: .label))
        } header: {
            Text("Photos").foregroundStyle(Color(uiColor: .label))
        }
    }

    private func optionalPicker<T: WatchOption>(_ title: LocalizedStringKey, selection: Binding<T?>) -> some View
    where T.AllCases: RandomAccessCollection {
        Picker(title, selection: selection) {
            Text("Not specified").tag(Optional<T>.none)
            ForEach(Array(T.allCases)) { Text($0.title).tag(Optional($0)) }
        }
    }

    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos = [] }
        for item in items {
            do {
                try Task.checkCancellation()
                guard let data = try await item.loadTransferable(type: ImportedImage.self) else {
                    throw CollectionError.unreadablePhoto
                }
                try Task.checkCancellation()
                let photo = try await store.photoStore.importPhoto(data.data)
                guard await assets.stage(photo.id) else { break }
                draft.photos.append(photo)
                if draft.mainPhotoID == nil { draft.mainPhotoID = photo.id }
            } catch is CancellationError { break } catch {
                errorMessage = String(
                    localized: "A photo could not be imported. Already imported photos are still available.")
            }
        }
    }

    private func removePhoto(_ photo: PhotoDraft) {
        draft.photos.removeAll { $0.id == photo.id }
        if draft.mainPhotoID == photo.id { draft.mainPhotoID = draft.photos.first?.id }
    }

    @MainActor private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        let oldIDs = Set((watch?.sortedPhotos.map(\.id) ?? []) + (wishlistItem?.photoID.map { [$0] } ?? []))
        let retainedIDs = Set(draft.photos.map(\.id))
        do {
            try store.save(draft, editing: watch, moving: wishlistItem, locale: locale)
            await assets.commit(retaining: retainedIDs, replacing: oldIDs)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
