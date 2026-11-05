import PhotosUI
import SwiftUI

struct WishlistEditorView: View {
    let store: CollectionStore
    let item: WishlistItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @Bindable var session: WishlistEditorSession
    private var initialDraft: WishlistDraft { session.initial }
    @State private var discarding = false
    private var draft: WishlistDraft {
        get { session.draft }
        nonmutating set { session.draft = newValue }
    }
    @State private var choosingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewPhoto: PhotoDraft?
    private var assets: DraftAssetSession { session.assets }
    private var saving: Bool {
        get { session.saving }
        nonmutating set { session.saving = newValue }
    }
    private var error: String? {
        get { session.error }
        nonmutating set { session.error = newValue }
    }

    init(store: CollectionStore, session: WishlistEditorSession) {
        self.store = store
        self.session = session
        self.item = session.item
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $session.draft.brand).accessibilityIdentifier("wish.brand")
                    TextField("Model", text: $session.draft.modelName).accessibilityIdentifier("wish.model")
                } header: {
                    Text("Watch").foregroundStyle(Color.supportingText)
                }
                Section {
                    if let photo = draft.photo {
                        Button {
                            previewPhoto = photo
                        } label: {
                            PhotoView(photo: photo, store: store.photoStore).frame(
                                height: widthClass == .regular ? 300 : heightClass == .compact ? 140 : 190)
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
                    TextField("Link", text: $session.draft.url).keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Target price", text: $session.draft.price).keyboardType(.decimalPad)
                    CurrencyPicker(selection: $session.draft.currencyCode)
                    Picker("Priority", selection: $session.draft.priority) {
                        ForEach(WishlistPriority.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Details").foregroundStyle(Color.supportingText)
                }
                Section {
                    TextField("Notes", text: $session.draft.notes, axis: .vertical).lineLimit(3...8)
                } header: {
                    Text("Notes").foregroundStyle(Color.supportingText)
                }
            }
            .disabled(saving)
            .navigationTitle(item == nil ? Text("Add to wishlist") : Text("Edit wish"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if draft != initialDraft { discarding = true } else { dismiss() }
                    }.tint(
                        Color(uiColor: .label)
                    ).disabled(
                        assets.isImporting || saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(!draft.purchaseDraft.hasRequiredFields || assets.isImporting || saving)
                        .accessibilityIdentifier("wish.save")
                }
            }
            .interactiveDismissDisabled(assets.isImporting || saving || draft != initialDraft)
            .fullScreenCover(item: $previewPhoto) { photo in
                WatchPhotoPreview(photo: photo, store: store.photoStore)
            }
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($session.error)
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                let photoStore = store.photoStore
                assets.run { [weak session, photoStore] in
                    do {
                        guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                            throw CollectionError.unreadablePhoto
                        }
                        try Task.checkCancellation()
                        let imported = try await photoStore.importPhoto(data.data)
                        guard let session else {
                            try? await photoStore.remove(imported.id)
                            return
                        }
                        guard await session.assets.stage(imported.id) else { return }
                        session.draft.photo = imported
                    } catch is CancellationError {} catch {
                        session?.error = String(localized: "This photo could not be read. Choose another image.")
                    }
                }
            }
            .onChange(of: assets.isImporting) {
                if !assets.isImporting { selectedPhoto = nil }
            }
        }
    }

    @MainActor private func save() async {
        guard !saving, !assets.isFinished, !assets.isImporting else { return }
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
