import PhotosUI
import SwiftUI

struct TimepieceEditorView: View {
    let store: CollectionStore
    let watch: Timepiece?
    let wishlistItem: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Bindable var session: TimepieceEditorSession
    private var initialDraft: TimepieceDraft { session.initial }
    @State private var discarding = false
    private var draft: TimepieceDraft {
        get { session.draft }
        nonmutating set { session.draft = newValue }
    }
    @State private var choosingPhotos = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importCount = 0
    private var assets: DraftAssetSession { session.assets }
    private var saving: Bool { session.saving }

    init(store: CollectionStore, session: TimepieceEditorSession) {
        self.store = store
        self.session = session
        self.watch = session.watch
        self.wishlistItem = session.wishlistItem
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $session.draft.brand).accessibilityIdentifier("editor.brand")
                    TextField("Model", text: $session.draft.modelName).accessibilityIdentifier("editor.model")
                } header: {
                    Text("Watch").foregroundStyle(Color(uiColor: .label))
                } footer: {
                    Text("Only brand and model are required.").foregroundStyle(Color(uiColor: .label))
                }

                photosSection

                Section {
                    optionalPicker("Device type", selection: $session.draft.deviceKind)
                    optionalPicker("Movement", selection: $session.draft.movementType)
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
                    TextField("Reference number", text: $session.draft.referenceNumber).textInputAutocapitalization(
                        .characters)
                    TextField("Serial number", text: $session.draft.serialNumber).textInputAutocapitalization(
                        .characters)
                    Picker("Status", selection: $session.draft.status) {
                        ForEach(WatchStatus.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Details").foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    OptionalDateField(
                        toggleTitle: "Add purchase date", dateTitle: "Purchase date",
                        selection: $session.draft.purchaseDate)
                    TextField("Purchase price", text: $session.draft.price).keyboardType(.decimalPad)
                        .accessibilityIdentifier("editor.price")
                    CurrencyPicker(selection: $session.draft.currencyCode)
                    TextField("Seller", text: $session.draft.seller)
                } header: {
                    Text("Purchase").foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    TextField("Notes", text: $session.draft.notes, axis: .vertical).lineLimit(3...8)
                } header: {
                    Text("Notes").foregroundStyle(Color(uiColor: .label))
                }
            }
            .disabled(saving)
            .navigationTitle(watch == nil ? Text("Add a watch") : Text("Edit watch"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if draft != initialDraft { discarding = true } else { dismiss() }
                    }.tint(
                        Color(uiColor: .label)
                    )
                    .disabled(assets.isImporting || saving)
                    .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(!draft.hasRequiredFields || assets.isImporting || assets.isFinished || saving)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .interactiveDismissDisabled(assets.isImporting || saving || draft != initialDraft)
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($session.error)
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                selectedPhotos = []
                importCount = items.count
                session.importPhotos(
                    items.map { item in
                        {
                            guard let imported = try await item.loadTransferable(type: ImportedImage.self) else {
                                throw CollectionError.unreadablePhoto
                            }
                            return imported.data
                        }
                    }, from: store.photoStore)
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
                                    .accessibilityIdentifier("editor.photo.remove.\(photo.id)")
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
                ProgressView(value: Double(assets.importedCount), total: Double(max(importCount, 1))) {
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

    private func removePhoto(_ photo: PhotoDraft) {
        draft.photos.removeAll { $0.id == photo.id }
        if draft.mainPhotoID == photo.id { draft.mainPhotoID = draft.photos.first?.id }
    }

    /// Dismisses the editor only after the draft and its files have been committed.
    @MainActor private func save() async {
        if await session.save(in: store, locale: locale) { dismiss() }
    }
}
