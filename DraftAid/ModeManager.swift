import Foundation
import Combine

struct DraftMode: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var icon: String
    var promptTemplate: String
    var outputLanguage: String
    var isDefault: Bool
    var isEnabled: Bool = true

    static let defaultModes: [DraftMode] = [
        DraftMode(
            id: "fixGrammar",
            name: "Fix Grammar",
            icon: "checkmark.circle",
            promptTemplate: "Fix spelling, grammar, and punctuation. Keep the original tone and meaning. Output in {{language}}.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "rewrite",
            name: "Rewrite",
            icon: "arrow.clockwise",
            promptTemplate: "Rewrite the following text for clarity and better flow. Keep the same meaning. Output in {{language}}.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "shorten",
            name: "Shorten",
            icon: "arrow.down.forward",
            promptTemplate: "Reduce to the shortest possible version while keeping the core message. Remove filler words. Output in {{language}}.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "casual",
            name: "Casual",
            icon: "face.smiling",
            promptTemplate: "Rewrite in a casual, friendly, conversational tone. Use contractions and simple words. Output in {{language}}.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "formal",
            name: "Formal",
            icon: "briefcase",
            promptTemplate: "Rewrite in a professional, formal business tone. No contractions. Polite and clear. Output in {{language}}.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "gitBranch",
            name: "Git Branch",
            icon: "arrow.triangle.branch",
            promptTemplate: "Convert the description into a conventional git branch name (conventionalbranch.org). Format: type/description. Types: feat, fix, hotfix, release, docs, style, refactor, perf, test, build, ci, chore. Pick the type that best fits the described work. Description: kebab-case (lowercase, hyphens between words), remove articles (a, an, the), keep the whole branch name under 50 chars. Output ONLY the branch name, no backticks, no explanation.",
            outputLanguage: "English",
            isDefault: true
        ),
        DraftMode(
            id: "commit",
            name: "Commit",
            icon: "text.badge.checkmark",
            promptTemplate: "Write a conventional commit message (conventionalcommits.org) for the following change description. Format: type(optional-scope): subject. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert. Scope: optional, lowercase noun in parentheses. Subject: imperative mood, lowercase first letter, no trailing period, under 72 characters. Output ONLY the commit message, no backticks, no explanation.",
            outputLanguage: "English",
            isDefault: true
        )
    ]
}

class ModeManager: ObservableObject {
    static let shared = ModeManager()
    @Published var modes: [DraftMode] = []

    private let key = "draftaid.customModes"

    var enabledModes: [DraftMode] {
        modes.filter { $0.isEnabled }
    }

    init() {
        load()
    }

    /// Prompts we have since improved. If a saved default mode still carries
    /// the old untouched prompt, upgrade it - but never clobber user edits.
    private static let legacyPrompts: [String: String] = [
        "gitBranch": "Convert the description into a valid git branch name. Rules: kebab-case (lowercase, hyphens between words), remove articles (a, an, the), keep under 50 chars. Output ONLY the branch name, no backticks, no explanation."
    ]

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([DraftMode].self, from: data) {
            // Merge defaults with saved (restore any missing defaults)
            var merged = saved
            for def in DraftMode.defaultModes {
                if !merged.contains(where: { $0.id == def.id }) {
                    merged.append(def)
                }
            }
            // Upgrade untouched legacy prompts to the current defaults
            for (index, mode) in merged.enumerated() {
                if let legacy = ModeManager.legacyPrompts[mode.id],
                   mode.promptTemplate == legacy,
                   let def = DraftMode.defaultModes.first(where: { $0.id == mode.id }) {
                    merged[index].promptTemplate = def.promptTemplate
                }
            }
            modes = merged.sorted { $0.name < $1.name }
        } else {
            modes = DraftMode.defaultModes
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(modes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addMode(name: String, icon: String, prompt: String, language: String) {
        let mode = DraftMode(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            promptTemplate: prompt,
            outputLanguage: language,
            isDefault: false
        )
        modes.append(mode)
        modes.sort { $0.name < $1.name }
        save()
    }

    func updateMode(_ updated: DraftMode) {
        guard let index = modes.firstIndex(where: { $0.id == updated.id }) else { return }
        modes[index] = updated
        save()
    }

    func deleteMode(id: String) {
        modes.removeAll { $0.id == id }
        save()
    }

    func resetToDefaults() {
        modes = DraftMode.defaultModes
        save()
    }
}
