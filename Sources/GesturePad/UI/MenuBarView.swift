import SwiftUI

struct MenuBarView: View {
    @State var configStore: ConfigStore
    @Environment(\.openWindow) private var openWindow

    private var activeCount: Int {
        GestureType.allCases.filter { configStore.action(for: $0) != .disabled }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GesturePad")
                        .font(.headline)
                    Text("\(activeCount) gesture\(activeCount == 1 ? "" : "s") active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $configStore.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Menu items
            VStack(spacing: 1) {
                menuButton("Settings…", icon: "gearshape") {
                    openWindow(id: "settings")
                    NSApp.activate()
                }

                menuButton("Quit GesturePad", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .frame(width: 240)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.clear)
        )
        .contentShape(Rectangle())
    }
}
