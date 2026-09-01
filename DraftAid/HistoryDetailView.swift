import SwiftUI

/// Debug/detail view for a single history entry: full input, full output,
/// and the token usage reported by the Gemini API.
struct HistoryDetailView: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Details")
                    .font(.headline)
                Spacer()
                SheetCloseButton()
            }

            HStack(spacing: 12) {
                Label(item.mode, systemImage: "tag")
                Text(item.timestamp, style: .date)
                Text(item.timestamp, style: .time)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Token usage (only present for entries made after this feature)
            if item.totalTokens != nil {
                HStack(spacing: 10) {
                    tokenBadge(label: "Input", value: item.promptTokens)
                    tokenBadge(label: "Output", value: item.completionTokens)
                    tokenBadge(label: "Total", value: item.totalTokens)
                }
            }

            Text("Input")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                Text(item.original)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 120)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)

            HStack {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.result, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            ScrollView {
                Text(item.result)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color.green.opacity(0.06))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    private func tokenBadge(label: String, value: Int?) -> some View {
        VStack(spacing: 2) {
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
    }
}
