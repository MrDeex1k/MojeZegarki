import SwiftUI

struct DocumentNotesView: View {
    let notes: String

    var body: some View {
        ScrollView {
            Text(notes)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .accessibilityIdentifier("document.fullNotes")
    }
}
