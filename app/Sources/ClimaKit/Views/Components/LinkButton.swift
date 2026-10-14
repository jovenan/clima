import SwiftUI

/// Subtle text/icon button (footer, notices).
struct LinkButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label().contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
