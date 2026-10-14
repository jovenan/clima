import SwiftUI

/// Round icon button (power, −/+). Fades when disabled.
struct CircleButton: View {
    let symbol: String
    var size: CGFloat = 36
    var filled = false
    var color: Color = .primary
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(filled ? Color.white : Color.primary)
                .background(Circle().fill(filled ? color : Color.primary.opacity(0.08)))
                .shadow(color: filled ? color.opacity(0.45) : .clear, radius: 6, y: 2)
                .contentShape(Circle())
                .opacity(isEnabled ? 1 : 0.3)
        }
        .buttonStyle(PressableStyle())
    }
}
