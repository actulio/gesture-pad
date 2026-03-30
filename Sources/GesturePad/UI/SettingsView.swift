import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State var engine: GestureEngine

    var body: some View {
        Form {
            Section("Gesture Test") {
                GestureTestPanel(engine: engine)
            }

            Section("Gesture Mappings") {
                ForEach(GestureType.allCases, id: \.self) { gestureType in
                    GestureRowView(
                        gestureType: gestureType,
                        action: Binding(
                            get: { engine.configStore.action(for: gestureType) },
                            set: { engine.configStore.setAction($0, for: gestureType) }
                        )
                    )
                }
            }

            Section("General") {
                Toggle("Enable Gestures", isOn: $engine.configStore.isEnabled)
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 450)
    }
}

struct GestureTestPanel: View {
    @State var engine: GestureEngine
    @State private var gestureLog: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status row
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(engine.debugStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Test Mode", isOn: $engine.testMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("When on, gestures are detected but NOT executed")
            }

            Divider()

            // Live stats
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("MT Devices:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(engine.deviceCount)")
                        .font(.caption.monospaced())
                }
                GridRow {
                    Text("Touch Events:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(engine.touchEventCount)")
                        .font(.caption.monospaced())
                }
                GridRow {
                    Text("Last Touch:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(engine.lastTouchInfo)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                }
                GridRow {
                    Text("Last Gesture:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(engine.lastGestureInfo)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(engine.lastGestureInfo.contains("No gesture") ? Color.secondary : Color.green)
                        .lineLimit(1)
                }
            }

            Divider()

            // Gesture log
            Text("Gesture Log")
                .font(.caption).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(gestureLog.enumerated()), id: \.offset) { i, entry in
                            Text(entry)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .id(i)
                        }
                        if gestureLog.isEmpty {
                            Text("Do a 3-finger tap or swipe on the trackpad...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: 80)
                .padding(6)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onChange(of: engine.lastGestureInfo) { _, newValue in
                    if !newValue.contains("No gesture") {
                        gestureLog.append(newValue)
                        // Keep last 50 entries
                        if gestureLog.count > 50 {
                            gestureLog.removeFirst(gestureLog.count - 50)
                        }
                        proxy.scrollTo(gestureLog.count - 1)
                    }
                }
            }

            // Actions
            HStack {
                Button("Clear Log") {
                    gestureLog.removeAll()
                }
                .controlSize(.small)

                Spacer()

                Button("Restart Engine") {
                    engine.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        engine.start()
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var statusColor: Color {
        if engine.debugStatus.contains("Active") { return .green }
        if engine.debugStatus.contains("Running") { return .yellow }
        if engine.debugStatus.contains("Failed") || engine.debugStatus.contains("Disabled") { return .red }
        return .gray
    }
}

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = !newValue
                }
            }
    }
}
