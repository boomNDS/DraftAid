import SwiftUI

/// Standard circular ✕ close button for sheets/modals.
/// Uses the sheet's own dismiss environment, so it works in any modal.
struct SheetCloseButton: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape)
        .help("Close")
    }
}
