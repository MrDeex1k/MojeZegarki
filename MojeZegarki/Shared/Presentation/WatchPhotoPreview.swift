import SwiftUI

struct WatchPhotoPreview: View {
    let photo: PhotoDraft
    let store: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loadedAsset: [String]?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Watch photo")
                        .accessibilityIdentifier("photoPreview.image")
                } else if loading {
                    ProgressView("Opening photo…").tint(.white)
                } else {
                    ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                        .accessibilityIdentifier("photoPreview.unavailable")
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("photoPreview.close")
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task(id: asset + [ImageLoader.access.revision.uuidString]) { [asset] in
            guard loadedAsset != asset || image == nil else { return }
            image = nil
            loading = true
            let prepared = await ImageLoader.load(photo, store: store, thumbnail: false)
            guard !Task.isCancelled else { return }
            loadedAsset = asset
            image = prepared
            loading = false
        }
    }

    private var asset: [String] { [store.root.path, photo.id.uuidString, photo.filename] }
}
