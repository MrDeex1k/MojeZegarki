import PhotosUI
import SwiftUI

struct WishlistEditorView: View {
    let store: CollectionStore
    let item: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private let initialDraft: WishlistDraft
    @State private var discarding = false
    @State private var draft: WishlistDraft
    @State private var choosingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewPhoto: PhotoDraft?
    @State private var assets: DraftAssetSession
    @State private var saving = false
    @State private var error: String?

    init(store: CollectionStore, item: WishlistItem? = nil) {
        self.store = store
        _assets = State(initialValue: DraftAssetSession { try await store.photoStore.remove($0) })
        self.item = item
        let initial = item.map { WishlistDraft(item: $0) } ?? WishlistDraft()
        initialDraft = initial
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $draft.brand).accessibilityIdentifier("wish.brand")
                    TextField("Model", text: $draft.modelName).accessibilityIdentifier("wish.model")
                } header: {
                    Text("Watch").foregroundStyle(Color.supportingText)
                }
                Section {
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
                    Button {
                        choosingPhoto = true
                    } label: {
                        Label("Choose photo", systemImage: "photo").fixedSize(horizontal: false, vertical: true).frame(
                            minHeight: 44)
                    }
                    .photosPicker(isPresented: $choosingPhoto, selection: $selectedPhoto, matching: .images)
                    .disabled(assets.isImporting)
                    if assets.isImporting {
                        ProgressView("Importing photos…")
                        Button("Stop importing") { assets.stop() }
                    }
                } header: {
                    Text("Photo").foregroundStyle(Color.supportingText)
                }
                Section {
                    TextField("Link", text: $draft.url).keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Target price", text: $draft.price).keyboardType(.decimalPad)
                    CurrencyPicker(selection: $draft.currencyCode)
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(WishlistPriority.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Details").foregroundStyle(Color.supportingText)
                }
                Section {
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...8)
                } header: {
                    Text("Notes").foregroundStyle(Color.supportingText)
                }
            }
            .disabled(saving)
            .navigationTitle(item == nil ? Text("Add to wishlist") : Text("Edit wish"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft != initialDraft { discarding = true } else { dismiss() } }.tint(
                        Color(uiColor: .label)
                    ).disabled(
                        assets.isImporting || saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!draft.purchaseDraft.hasRequiredFields || assets.isImporting || saving)
                        .accessibilityIdentifier("wish.save")
                }
            }
            .interactiveDismissDisabled(assets.isImporting || saving || draft != initialDraft)
            .fullScreenCover(item: $previewPhoto) { photo in
                WatchPhotoPreview(photo: photo, store: store.photoStore)
            }
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($error)
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                assets.run {
                    defer { selectedPhoto = nil }
                    do {
                        guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                            throw CollectionError.unreadablePhoto
                        }
                        let imported = try await store.photoStore.importPhoto(data.data)
                        guard await assets.stage(imported.id) else { return }
                        draft.photo = imported
                    } catch is CancellationError {} catch {
                        self.error = String(localized: "This photo could not be read. Choose another image.")
                    }
                }
            }
        }
    }

    @MainActor private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        let oldID = item?.photoID
        do {
            try store.saveWish(draft, editing: item, locale: locale)
            await assets.commit(
                retaining: Set(draft.photo.map { [$0.id] } ?? []), replacing: Set(oldID.map { [$0] } ?? []))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
