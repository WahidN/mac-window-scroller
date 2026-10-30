import SwiftUI

struct ShortcutsView: View {
    private struct Shortcut {
        let keys: [String]
        let action: String
    }

    private static let shortcuts = [
        Shortcut(keys: ["⌃", "⌥", "C"], action: "Add or remove the focused window"),
        Shortcut(keys: ["⌃", "⌥", "F"], action: "Toggle full width"),
        Shortcut(keys: ["⌃", "⌥", "←"], action: "Move the window one place left"),
        Shortcut(keys: ["⌃", "⌥", "→"], action: "Move the window one place right"),
        Shortcut(keys: ["⌃", "⌥", "X"], action: "Drop the window with the orange border"),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(Self.shortcuts, id: \.action) { shortcut in
                GridRow {
                    HStack(spacing: 4) {
                        ForEach(shortcut.keys, id: \.self, content: KeyCap.init)
                    }
                    Text(shortcut.action)
                }
            }
            Divider().gridCellUnsizedAxes(.horizontal)
            GridRow {
                Image(systemName: "hand.draw")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                Text("Three-finger swipe to scroll the strip")
            }
            GridRow {
                HStack(spacing: 6) {
                    KeyCap(key: "⌥")
                    Image(systemName: "computermouse")
                        .font(.title3)
                }
                .frame(maxWidth: .infinity)
                Text("Hold and scroll sideways with a mouse")
            }
        }
        .padding(.vertical, 8)
        .fixedSize()
    }
}

private struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(width: 26, height: 24)
            .background(.quaternary, in: .rect(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.tertiary))
    }
}
