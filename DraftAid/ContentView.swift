import SwiftUI
import AppKit

struct ContentView: View {
    var onDismiss: () -> Void

    @StateObject private var modeManager = ModeManager.shared
    @State private var input = ""
    @State private var modeIndex = 0
    @State private var output = ""
    @State private var history: [HistoryItem] = []
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showAPISettings = false
    @State private var isProcessing = false
    @State private var didCopy = false
    @State private var lastRunFailed = false
    @State private var hasAPIKey = true
    @State private var outputModeId = ""
    @AppStorage(AIEngine.defaultsKey) private var engineRaw = AIEngine.apple.rawValue

    private var engine: AIEngine {
        AIEngine(rawValue: engineRaw) ?? .apple
    }

    var currentMode: DraftMode? {
        let enabled = modeManager.enabledModes
        guard !enabled.isEmpty else { return nil }
        let idx = modeIndex % enabled.count
        return enabled[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ─── TOP INPUT BAR ───
            HStack(spacing: 12) {
                // Mode Badge
                if let mode = currentMode {
                    ModeBadge(mode: mode)
                        .id(mode.id)
                        .transition(.opacity)
                }

                // Input Field
                ZStack(alignment: .leading) {
                    if input.isEmpty {
                        Text("Type something...")
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.leading, 4)
                    }

                    CommandInput(
                        text: $input,
                        onTab: cycleMode,
                        onEnter: process,
                        onEscape: onDismiss
                    )
                    .frame(height: 28)
                }

                Spacer()

                // History Button
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("History")

                // AI Engine Button
                Button {
                    showAPISettings = true
                } label: {
                    Image(systemName: "cpu")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("AI Engine")

                // Settings Button
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Settings")

                // Close Button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // ─── OUTPUT AREA ───
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.opacity)
            } else if !output.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(lastRunFailed ? "Error" : "Result")
                            .font(.caption)
                            .foregroundColor(lastRunFailed ? .red : .secondary)

                        Spacer()

                        if lastRunFailed {
                            Button {
                                process()
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                            didCopy = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                didCopy = false
                            }
                        } label: {
                            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(didCopy ? .green : .accentColor)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }

                    ScrollView {
                        Text(output)
                            .font(.system(size: 14, design: ["gitBranch", "commit"].contains(outputModeId) ? .monospaced : .default))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(maxHeight: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(lastRunFailed ? Color.red.opacity(0.06) : Color.green.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(lastRunFailed ? Color.red.opacity(0.25) : Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }

            // ─── FIRST-RUN SETUP CARD ───
            if engine == .gemini && !hasAPIKey {
                VStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                    Text("Set up your free API key")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Cloud mode runs on Google's Gemini with your own key. Free to create — takes about a minute.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")!)
                        } label: {
                            Label("Get Free Key", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)

                        Button("I Have a Key") {
                            showAPISettings = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.small)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // ─── ON-DEVICE MODEL UNAVAILABLE ───
            if engine == .apple, let message = LocalModelService.shared.availabilityMessage {
                VStack(spacing: 10) {
                    Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                    Text("On-device model unavailable")
                        .font(.system(size: 14, weight: .semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Use Gemini Cloud Instead") {
                        engineRaw = AIEngine.gemini.rawValue
                        showAPISettings = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // ─── RECENT HISTORY (last 3) ───
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Recent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("View All") {
                            showHistory = true
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.bottom, 2)

                    ForEach(history.prefix(3)) { item in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.result, forType: .string)
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.result)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                if let total = item.totalTokens {
                                    Text("\(total) tok")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                Text(item.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Click to copy")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // ─── MODE SWITCHER HINT ───
            HStack(spacing: 6) {
                ForEach(modeManager.enabledModes.prefix(4)) { mode in
                    let isActive = currentMode?.id == mode.id
                    Button {
                        if let idx = modeManager.enabledModes.firstIndex(where: { $0.id == mode.id }) {
                            modeIndex = idx
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10))
                            Text(mode.name)
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Color.blue.opacity(0.15) : Color.clear)
                        .foregroundColor(isActive ? .blue : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isActive ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if modeManager.enabledModes.count > 4 {
                    Text("+\(modeManager.enabledModes.count - 4)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Tab ↹ cycle · Enter ↵ go · Esc ✕ close")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Spacer()
        }
        .frame(width: 640, height: 420)
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            history = LocalStorage.shared.load()
            hasAPIKey = GeminiService.shared.hasAPIKey
        }
        .onChange(of: showAPISettings) {
            if !showAPISettings {
                hasAPIKey = GeminiService.shared.hasAPIKey
            }
        }
        .sheet(isPresented: $showSettings) {
            ModeSettingsView()
                .frame(width: 520, height: 540)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(history: $history)
                .frame(width: 520, height: 540)
        }
        .sheet(isPresented: $showAPISettings) {
            APISettingsView()
                .frame(width: 420, height: 420)
        }
    }

    private func cycleMode() {
        let enabled = modeManager.enabledModes
        guard enabled.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            modeIndex = (modeIndex + 1) % enabled.count
        }
    }

    private func process() {
        guard !input.isEmpty, let mode = currentMode else { return }

        isProcessing = true
        output = ""
        let text = input

        // "Auto" means: answer in whatever language the input is in
        let languageInstruction = mode.outputLanguage == "Auto"
            ? "the same language as the input"
            : mode.outputLanguage
        let prompt = mode.promptTemplate
            .replacingOccurrences(of: "{{language}}", with: languageInstruction)
            + "\n\nINPUT:\n\(text)\n\nOUTPUT:"

        Task {
            var generation: GenerationResult?
            var errorText: String?
            do {
                if engine == .gemini {
                    generation = try await GeminiService.shared.generate(prompt: prompt)
                } else {
                    generation = try await LocalModelService.shared.generate(prompt: prompt)
                }
            } catch {
                errorText = error.localizedDescription
            }

            await MainActor.run {
                if let generation = generation {
                    let item = HistoryItem(
                        id: UUID(),
                        timestamp: Date(),
                        mode: mode.name,
                        original: text,
                        result: generation.text,
                        promptTokens: generation.promptTokens,
                        completionTokens: generation.completionTokens,
                        totalTokens: generation.totalTokens
                    )
                    withAnimation(.easeOut(duration: 0.15)) {
                        output = generation.text
                        outputModeId = mode.id
                        isProcessing = false
                        lastRunFailed = false
                        history.insert(item, at: 0)
                        history = Array(history.prefix(100)) // cap stored history
                    }
                    LocalStorage.shared.save(history)
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        output = "⚠️ \(errorText ?? "Unknown error")"
                        outputModeId = mode.id
                        isProcessing = false
                        lastRunFailed = true
                    }
                }
            }
        }
    }
}

// MARK: - Mode Badge
struct ModeBadge: View {
    let mode: DraftMode

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mode.icon)
                .font(.system(size: 11))
            Text(mode.name)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.12))
        )
        .foregroundColor(.blue)
        .overlay(
            Capsule()
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Full History Sheet
struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var history: [HistoryItem]
    @State private var selectedItem: HistoryItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    history = []
                    LocalStorage.shared.save([])
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .disabled(history.isEmpty)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                SheetCloseButton()
            }
            .padding()

            if history.isEmpty {
                Spacer()
                Text("No history yet")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.mode)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                            if let total = item.totalTokens {
                                Text("\(total) tok")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Button {
                                selectedItem = item
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Details (input, output, tokens)")
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.result, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy result")
                        }
                        Text(item.original)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(item.result)
                            .font(.body)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedItem) { item in
            HistoryDetailView(item: item)
                .frame(width: 440, height: 460)
        }
    }
}

// MARK: - Visual Effect Blur (macOS Background)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        // Rounded window corners (the panel itself is borderless and clear)
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
