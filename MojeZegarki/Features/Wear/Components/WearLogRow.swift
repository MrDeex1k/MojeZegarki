import SwiftUI

struct WearLogRow: View {
    let log: WearLog
    let store: CollectionStore
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var brandFontSize = 18.75
    @ScaledMetric(relativeTo: .headline) private var modelFontSize = 20
    var body: some View {
        if let owner = log.timepiece {
            Button {
                onEdit()
            } label: {
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))) {
                        PhotoView(
                            photo: owner.mainPhoto.map {
                                PhotoDraft(id: $0.id, filename: $0.filename)
                            }, store: store.photoStore
                        )
                        .frame(width: 50, height: 58).clipShape(
                            RoundedRectangle(cornerRadius: 8))
                        WatchIdentityLabel(
                            brand: owner.brand, model: owner.modelName,
                            status: owner.status != .owned ? owner.status : nil, brandColor: Color(uiColor: .label),
                            brandFont: .system(size: brandFontSize),
                            modelFont: .system(size: modelFontSize, weight: .semibold),
                            modelColor: Color("WatchModelGold"))
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(Color(uiColor: .label))
                    }
            }
            .accessibilityIdentifier("wear.log.\(log.id)")
            .id("wear.result.\(log.id)")
            .swipeActions { Button("Delete", role: .destructive) { onDelete() } }
            .contextMenu {
                Button("Edit") { onEdit() }
                Button("Delete", role: .destructive) { onDelete() }
            }
        }
    }
}
