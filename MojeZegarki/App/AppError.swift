import SwiftUI

extension View {
    func appError(_ error: Binding<String?>) -> some View {
        alert("Something went wrong", isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { Text(error.wrappedValue ?? "") }
    }
}
