import PhotosUI
import SwiftUI

struct WishlistEditorView: View {
    let store: CollectionStore
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
    private var saving: Bool { session.saving }

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
            .navigationTitle(session.item == nil ? Text("Add to wishlist") : Text("Edit wish"))
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
                    Button("Save", systemImage: "checkmark") {
                        Task {
                            if await session.save(in: store, locale: locale) { dismiss() }
                        }
                    }
                    .disabled(
                        !draft.purchaseDraft.hasRequiredFields || assets.isImporting || assets.isFinished || saving
                    )
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
                defer { selectedPhoto = nil }
                guard let photo else { return }
                session.importPhoto(from: store.photoStore) {
                    guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                        throw CollectionError.unreadablePhoto
                    }
                    return data.data
                }
            }
        }
    }
}
