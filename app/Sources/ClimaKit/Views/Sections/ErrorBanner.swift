import SwiftUI

/// Yellow notice with the error message and a "Retry" button.
struct ErrorBanner: View {
    @EnvironmentObject private var store: ClimateStore
    let error: BackendError

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(error.message).font(.system(size: 11)).lineLimit(3)
            Spacer()
            LinkButton { Task { await store.refresh() } } label: {
                Text("Retry").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.yellow.opacity(0.12)))
    }
}
