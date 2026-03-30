import SwiftUI

struct MenuBarView: View {
    @State var configStore: ConfigStore
    let onOpenSettings: () -> Void

    private var activeCount: Int {
        GestureType.allCases.filter { configStore.action(for: $0) != .disabled }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("GesturePad")
                        .font(.headline)
                    Text("\(activeCount) gestures active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $configStore.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Button(action: onOpenSettings) {
                Label("Settings…", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .frame(width: 240)
    }
}
