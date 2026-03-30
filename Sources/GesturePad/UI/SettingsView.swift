import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Gesture Mappings") {
                ForEach(GestureType.allCases, id: \.self) { gestureType in
                    GestureRowView(
                        gestureType: gestureType,
                        action: Binding(
                            get: { configStore.action(for: gestureType) },
                            set: { configStore.setAction($0, for: gestureType) }
                        )
                    )
                }
            }

            Section("General") {
                Toggle("Enable Gestures", isOn: $configStore.isEnabled)
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 300)
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
