import SwiftUI
import SwiftData

struct TimepieceDetailView: View {
    let watch: Timepiece
    let store: CollectionStore
    @Query private var allWearLogs: [WearLog]
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title2) private var titleFontSize = 24
    @State private var editing = false
    @State private var showingDocuments = false
    @State private var showingWear = false
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var errorMessage: String?

    init(watch: Timepiece, store: CollectionStore) {
        self.watch = watch
        self.store = store
    }

    private var wearLogs: [WearLog] { allWearLogs.filter { $0.timepiece?.id == watch.id } }

    var body: some View {
        List {
            if !watch.sortedPhotos.isEmpty {
                Section {
                    VStack(spacing: 0) {
                        TabView {
                            ForEach(orderedPhotos) { photo in
                                PhotoView(photo: PhotoDraft(id: photo.id, filename: photo.filename), store: store.photoStore, thumbnail: false)
                                    .accessibilityHidden(false)
                                    .accessibilityLabel("Watch photo")
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: orderedPhotos.count > 1 ? .always : .never))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        .frame(height: 300)
                        if watch.status == .owned {
                            WearTodayButton(watch: watch, store: store)
                                .padding(16)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Text(watch.brand)) \(Text(watch.modelName).fontWeight(.semibold))")
                        .font(.system(size: titleFontSize))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("detail.model")
                    Text(watch.status.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if watch.sortedPhotos.isEmpty && watch.status == .owned {
                    WearTodayButton(watch: watch, store: store)
                        .padding(.vertical, 4)
                }
            }
            Section("Wearing") {
                Button { showingWear = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wearSummaryText)
                                .foregroundStyle(Color(uiColor: .label))
                            Text("View summary and history")
                                .font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("detail.wear")
            }
            Section {
                Button { showingDocuments = true } label: { Label("Documents", systemImage: "doc.text") }
                .accessibilityIdentifier("detail.documents")
            }
            if hasDetails {
                Section("Details") {
                    if let kind = watch.deviceKindRaw.flatMap(DeviceKind.init(rawValue:)) {
                        LabeledContent("Device type") { Text(kind.title) }
                    }
                    if let movement = watch.movementTypeRaw.flatMap(MovementType.init(rawValue:)) {
                        LabeledContent("Movement") { Text(movement.title) }
                    }
                    if !watch.categoryIDs.isEmpty {
                        LabeledContent("Categories", value: watch.categoryIDs.compactMap(WatchCategory.init(rawValue:)).map { String(localized: $0.title) }.joined(separator: ", "))
                    }
                    if let value = watch.referenceNumber { LabeledContent("Reference number", value: value) }
                    if let value = watch.serialNumber { LabeledContent("Serial number", value: value).privacySensitive() }
                }
            }
            if watch.purchaseDate != nil || watch.purchasePrice != nil || watch.seller != nil {
                Section("Purchase") {
                    if let date = watch.purchaseDate { LabeledContent("Purchase date", value: date.formatted(date: .abbreviated, time: .omitted)) }
                    if let price = watch.purchasePrice, let decimal = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")), let currency = watch.currencyCode {
                        LabeledContent("Purchase price", value: decimal.formatted(.currency(code: currency))).privacySensitive()
                    }
                    if let seller = watch.seller { LabeledContent("Seller", value: seller) }
                }
            }
            if let notes = watch.notes { Section("Notes") { Text(notes) } }
            Section {
                if watch.status == .owned {
                    Button("Mark as sold", systemImage: "archivebox") { changeStatus(.sold) }.accessibilityIdentifier("detail.sell")
                    Button("Mark as destroyed", systemImage: "archivebox") { changeStatus(.destroyed) }
                } else {
                    Button("Restore to collection", systemImage: "arrow.uturn.backward") { changeStatus(.owned) }
                        .accessibilityIdentifier("detail.restore")
                }
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete permanently", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                    .tint(.red)
                    .accessibilityIdentifier("detail.delete")
            } footer: {
                Text("Archiving keeps all photos and history. Permanent deletion cannot be undone.")
            }
        }
        .disabled(deleting)
        .navigationTitle(watch.modelName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(watch.modelName)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { editing = true }
                    .accessibilityIdentifier("detail.edit")
            }
        }
        .sheet(isPresented: $editing) { TimepieceEditorView(store: store, watch: watch) }
        .sheet(isPresented: $showingDocuments) {
            NavigationStack {
                DocumentsView(watch: watch, store: store, onClose: { showingDocuments = false })
            }
        }
        .sheet(isPresented: $showingWear) {
            NavigationStack {
                WearView(store: store, watch: watch)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Done") { showingWear = false } }
                    }
            }
        }
        .confirmationDialog("Delete this watch permanently?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                deleting = true
                Task {
                    do { try await store.delete(watch); dismiss() }
                    catch { errorMessage = error.localizedDescription; deleting = false }
                }
            }
            .accessibilityIdentifier("confirm.delete")
        } message: { Text("The watch, photos, documents and wear history will be removed from this iPhone.") }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var wearSummaryText: AttributedString {
        let count = Set(wearLogs.map(\.calendarDay)).count
        let text = String(localized: "Worn for **\(count)** days")
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private var orderedPhotos: [TimepiecePhoto] {
        guard let main = watch.mainPhoto else { return watch.sortedPhotos }
        return [main] + watch.sortedPhotos.filter { $0.id != main.id }
    }

    private var hasDetails: Bool {
        watch.deviceKindRaw != nil || watch.movementTypeRaw != nil || !watch.categoryIDs.isEmpty ||
        watch.referenceNumber != nil || watch.serialNumber != nil
    }

    private func changeStatus(_ status: WatchStatus) {
        do { try store.changeStatus(status, for: watch) }
        catch { errorMessage = error.localizedDescription }
    }
}
