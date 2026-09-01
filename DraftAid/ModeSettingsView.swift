import SwiftUI

struct ModeSettingsView: View {
    @StateObject private var manager = ModeManager.shared
    @State private var editingMode: DraftMode?
    @State private var showAddSheet = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Modes")
                    .font(.headline)
                Spacer()
                Button("Reset Defaults") {
                    showResetConfirm = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)

                Button("+ Add Mode") {
                    showAddSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                SheetCloseButton()
            }
            .padding()

            List {
                ForEach($manager.modes) { $mode in
                    ModeRow(mode: $mode, onEdit: {
                        editingMode = mode
                    })
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let mode = manager.modes[index]
                        if !mode.isDefault {
                            manager.deleteMode(id: mode.id)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .confirmationDialog("Reset all modes to defaults?", isPresented: $showResetConfirm) {
            Button("Reset Defaults", role: .destructive) {
                manager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Custom modes will be deleted.")
        }
        .sheet(item: $editingMode) { mode in
            ModeEditorView(mode: mode, isNew: false)
                .frame(width: 480, height: 520)
        }
        .sheet(isPresented: $showAddSheet) {
            ModeEditorView(
                mode: DraftMode(
                    id: UUID().uuidString,
                    name: "",
                    icon: "wand.and.stars",
                    promptTemplate: "Transform the following text. Output in {{language}}.",
                    outputLanguage: "English",
                    isDefault: false
                ),
                isNew: true
            )
            .frame(width: 480, height: 520)
        }
    }
}

struct ModeRow: View {
    @Binding var mode: DraftMode
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .frame(width: 24)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.name)
                    .font(.system(size: 13, weight: .medium))
                Text(mode.outputLanguage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $mode.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: mode.isEnabled) {
                    ModeManager.shared.save()
                }

            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct ModeEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var mode: DraftMode
    let isNew: Bool

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var prompt: String = ""
    @State private var language: String = ""

    let commonIcons = [
        "wand.and.stars", "checkmark.circle", "arrow.clockwise",
        "face.smiling", "briefcase", "arrow.triangle.branch",
        "text.quote", "sparkles", "pencil", "doc.text",
        "message", "envelope", "paperplane", "link"
    ]

    let languages = ["English", "Thai", "Japanese", "Korean", "Chinese", "Spanish", "French", "German", "Vietnamese", "Indonesian", "Auto"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isNew ? "New Mode" : "Edit Mode")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                SheetCloseButton()
            }

            ScrollView {
                Group {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. Email Subject", text: $name)

                    Text("Output Language")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $language) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(commonIcons, id: \.self) { ic in
                            Image(systemName: ic)
                                .frame(width: 28, height: 28)
                                .background(icon == ic ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(icon == ic ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    icon = ic
                                }
                        }
                    }

                    Text("Prompt Template")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $prompt)
                        .font(.system(size: 12))
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)

                    Text("Available placeholders: {{language}} (auto-filled)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                )
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            name = mode.name
            icon = mode.icon
            prompt = mode.promptTemplate
            language = mode.outputLanguage
        }
    }

    private func save() {
        var updated = mode
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.icon = icon
        updated.promptTemplate = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.outputLanguage = language

        if isNew {
            ModeManager.shared.addMode(
                name: updated.name,
                icon: icon,
                prompt: updated.promptTemplate,
                language: language
            )
        } else {
            ModeManager.shared.updateMode(updated)
        }
        dismiss()
    }
}
