import SwiftUI

/// Loads a value with `load`, showing progress / error / content, with pull-to-refresh.
struct AsyncContent<T, Content: View>: View {
    let load: () async throws -> T
    @ViewBuilder let content: (T) -> Content
    @State private var value: T?
    @State private var error: String?

    var body: some View {
        Group {
            if let value {
                content(value)
            } else if let error {
                ContentUnavailableView {
                    Label("Ошибка", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Повторить") { Task { await reload() } }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { if value == nil { await reload() } }
        .refreshable { await reload() }
    }

    private func reload() async {
        do {
            value = try await load()
            error = nil
        } catch {
            if value == nil { self.error = error.localizedDescription }
        }
    }
}
