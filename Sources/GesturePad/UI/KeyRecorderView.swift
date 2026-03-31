import SwiftUI
import Carbon.HIToolbox

struct KeyRecorderView: View {
    let onRecord: (UInt64, UInt16) -> Void
    let onCancel: () -> Void

    @State private var displayText = "Press shortcut…"
    @State private var monitor: Any?

    var body: some View {
        Text(displayText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
            .onAppear { startListening() }
            .onDisappear { stopListening() }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
    }

    private func startListening() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let cgFlags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
            let keyCode = UInt16(event.keyCode)

            if keyCode == UInt16(kVK_Escape) {
                onCancel()
            } else {
                onRecord(cgFlags.rawValue, keyCode)
            }
            return nil
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
