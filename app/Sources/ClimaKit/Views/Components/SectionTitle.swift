import SwiftUI

/// Uppercase section title, with an optional summary on the right.
struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// Small icon next to the text.
struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 9))
            configuration.title
        }
    }
}
