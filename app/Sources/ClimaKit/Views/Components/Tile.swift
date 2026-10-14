import SwiftUI

/// Rectangular button that gets colored when selected (modes, louvers, Eco/Turbo...).
struct Tile<Content: View>: View {
    let selected: Bool
    let color: Color
    var height: CGFloat = 40
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundStyle(selected ? color : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? color.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? color.opacity(0.55) : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
