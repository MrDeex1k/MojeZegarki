import SwiftUI

struct WatchPhotoPreview: View {
    let photo: PhotoDraft
    let store: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
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
                    ProgressView().tint(.white)
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
        .task(id: photo.id) {
            image = nil
            loading = true
            let prepared = await ImageLoader.load(photo, store: store, thumbnail: false)
            guard !Task.isCancelled else { return }
            image = prepared
            loading = false
        }
    }
}
