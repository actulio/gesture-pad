import SwiftUI

struct GestureRowView: View {
    let gestureType: GestureType
    @Binding var action: ActionType
    @State private var isRecordingShortcut = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(gestureType.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(gestureType.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecordingShortcut {
                KeyRecorderView { modifiers, keyCode in
                    action = .keyboardShortcut(modifiers: modifiers, keyCode: keyCode)
                    isRecordingShortcut = false
                } onCancel: {
                    isRecordingShortcut = false
                }
                .frame(width: 160)
            } else {
                actionPicker
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionPicker: some View {
        Menu {
            Button("🖱️ Middle Click") { action = .middleClick }
            Button("⌨️ Record Shortcut…") { isRecordingShortcut = true }
            Divider()
            Button("Disabled") { action = .disabled }
        } label: {
            Text(action.displayName)
                .font(.caption)
                .frame(minWidth: 120, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 160)
    }
}
