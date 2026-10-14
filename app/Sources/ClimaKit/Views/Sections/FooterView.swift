import AppKit
import SwiftUI

/// Connection status, "updated…", refresh and quit.
struct FooterView: View {
    @EnvironmentObject private var store: ClimateStore

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            TimelineView(.periodic(from: .now, by: 5)) { context in
                Text(statusText(now: context.date)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            LinkButton { Task { await store.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolEffect(.pulse, isActive: store.busy)
                    .frame(width: 22, height: 22)
            }
            .disabled(store.busy)
            .help("Refresh (⌘R)")
            .keyboardShortcut("r")

            LinkButton { NSApp.terminate(nil) } label: {
                Text("Quit").font(.system(size: 11, weight: .medium)).frame(height: 22)
            }
            .keyboardShortcut("q")
        }
        .foregroundStyle(.secondary)
    }

    private var dotColor: Color {
        if store.error != nil { return .orange }
        return store.lastUpdate == nil ? .secondary : .green
    }

    func statusText(now: Date) -> String {
        guard let last = store.lastUpdate else {
            return store.error != nil ? "No connection" : "Connecting…"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        let seconds = now.timeIntervalSince(last)
        let when = seconds < 10 ? "just now" : formatter.localizedString(for: last, relativeTo: now)
        return store.error != nil ? "Failed · last reading \(when)" : "Updated \(when)"
    }
}
