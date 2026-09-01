import SwiftUI

struct APISettingsView: View {
    @State private var apiKey = ""
    @State private var hasStoredKey = false
    @State private var clipboardKey: String?
    @State private var validationState: ValidationState = .idle
    @AppStorage(AIEngine.defaultsKey) private var engineRaw = AIEngine.apple.rawValue
    @AppStorage("draftaid.model") private var selectedModel = GeminiService.defaultModel

    enum ValidationState {
        case idle, validating, valid, failed(String)
    }

    private var engine: AIEngine {
        AIEngine(rawValue: engineRaw) ?? .apple
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("AI Engine")
                        .font(.headline)
                    Spacer()
                    SheetCloseButton()
                }

            Text("Engine")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: $engineRaw) {
                ForEach(AIEngine.allCases, id: \.rawValue) { engine in
                    Text(engine.label).tag(engine.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if engine == .apple {
                appleSection
            } else {
                geminiSection
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .onAppear {
            hasStoredKey = GeminiService.shared.hasAPIKey
            detectClipboardKey()
        }
    }

    // MARK: - On-device (Apple)
    private var appleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = LocalModelService.shared.availabilityMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Apple Intelligence is ready.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Text("Processing happens entirely on this Mac. Nothing is sent anywhere, no key needed.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Cloud (Gemini)
    private var geminiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DraftAid will call Google's Gemini API with your own key. You only pay Google for what you use.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: $selectedModel) {
                ForEach(GeminiService.availableModels, id: \.id) { model in
                    Text(model.label).tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            SecureField("Paste your API key here", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            // One-tap fill if a Gemini key is sitting on the clipboard
            if let clipboardKey = clipboardKey {
                Button {
                    apiKey = clipboardKey
                    self.clipboardKey = nil
                } label: {
                    Label("Use key from clipboard", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Link("Get a free key at Google AI Studio →",
                 destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)

            HStack(spacing: 10) {
                Button("Save & Verify") { saveAndVerify() }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedKey.isEmpty)

                if hasStoredKey {
                    Button("Remove Key", role: .destructive) {
                        KeychainHelper.delete(key: "geminiAPIKey")
                        hasStoredKey = false
                        validationState = .idle
                    }
                    .buttonStyle(.borderless)
                }

                validationStatus
            }

            Text("Your key is stored in the macOS Keychain (this device only) and is sent only to Google over HTTPS.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var validationStatus: some View {
        switch validationState {
        case .idle:
            if hasStoredKey {
                Label("Key stored", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .validating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Verifying...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .valid:
            Label("Key verified", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)
        }
    }

    /// Gemini API keys start with "AIza". If one is on the clipboard,
    /// offer to fill it in so the user doesn't have to paste manually.
    private func detectClipboardKey() {
        guard let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            clip.range(of: #"^AIza[A-Za-z0-9_\-]{20,}$"#, options: .regularExpression) != nil
        else { return }
        clipboardKey = clip
    }

    private func saveAndVerify() {
        let key = trimmedKey
        KeychainHelper.save(key: "geminiAPIKey", value: key)
        apiKey = ""
        hasStoredKey = true
        validationState = .validating

        Task {
            do {
                try await GeminiService.shared.validateKey(key)
                await MainActor.run { validationState = .valid }
            } catch {
                await MainActor.run { validationState = .failed(error.localizedDescription) }
            }
        }
    }
}
