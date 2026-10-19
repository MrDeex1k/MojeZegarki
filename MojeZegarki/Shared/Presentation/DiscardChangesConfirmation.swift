import SwiftUI

extension View {
    func discardChangesConfirmation(isPresented: Binding<Bool>, discard: @escaping () -> Void) -> some View {
        confirmationDialog("Discard unsaved changes?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive, action: discard)
        }
    }
}
