# DraftAid

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?style=flat&logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![macOS](https://img.shields.io/badge/macOS-26+-000000?style=flat&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Gemini](https://img.shields.io/badge/Gemini-4285F4?style=flat&logo=google&logoColor=white)](https://ai.google.dev/)

A fast macOS menu bar utility that transforms text based on the selected mode. Press a global hotkey, type, hit Enter, copy the result.

## Features

- **On-device by default** — Apple's local model (Apple Intelligence) handles everything offline, free, no setup
- **Optional Gemini cloud** — bring your own Google API key for higher quality
- **Menu bar only** — lives as a pencil icon in the status bar, no dock icon, no main window
- **Global hotkey** — `Cmd+Shift+T` opens the floating panel from anywhere
- **Keyboard-driven flow** — `Tab` cycles modes, `Enter` processes, `Esc` closes
- **6 built-in modes** — Fix Grammar, Rewrite, Shorten, Casual, Formal, Git Branch
- **Custom modes** — add your own with a custom prompt template, icon, and output language
- **History** — last 3 entries shown inline (click to copy), full history in a separate sheet
- **Local persistence** — modes in UserDefaults, history in JSON

## Usage

1. Click the pencil icon in the menu bar, or press `Cmd+Shift+T`
2. Type or paste text in the input field
3. Press `Tab` to cycle modes (or click a mode pill)
4. Press `Enter` to process
5. Click **Copy** to copy the result

## Built-in Modes

| Mode | What it does |
|---|---|
| Fix Grammar | Fixes spelling, grammar, punctuation |
| Rewrite | Rewrites for clarity and flow |
| Shorten | Cuts to the core message |
| Casual | Friendly, conversational tone |
| Formal | Professional business tone |
| Git Branch | Converts text to a [Conventional Branch](https://conventionalbranch.org/) name (`type/kebab-description`) |
| Commit | Writes a [Conventional Commits](https://www.conventionalcommits.org/) message (`type(scope): subject`) |

Custom modes are managed via the gear icon → **Modes**. Each mode has a prompt template with a `{{language}}` placeholder, an output language, and an enable/disable toggle. Default modes can be toggled but not edited.

## AI Engines

DraftAid processes text **on-device by default** using Apple's Foundation Models (Apple Intelligence, macOS 26+) — free, private, offline, zero configuration.

For higher-quality results, switch to **Cloud (Gemini)** in the engine settings (cpu icon in the panel):

1. Get a free key at [Google AI Studio](https://aistudio.google.com/apikey)
2. Pick "Cloud (Gemini)" as the engine
3. Paste the key and Save & Verify
4. Optionally pick a model (default: `gemini-flash-latest`, which auto-updates to the newest Flash release; stable and budget options available). If the chosen model is overloaded, DraftAid retries with backoff and falls back to a stable model automatically.

Security details (cloud mode):

- The key is stored in the **macOS Keychain**, marked this-device-only (no iCloud sync)
- It is sent only to `generativelanguage.googleapis.com` over HTTPS, in the `x-goog-api-key` header (never in the URL)
- It never appears in history, UserDefaults, or logs
- Tip: restrict the key to the *Generative Language API* in AI Studio so a leaked key can't be used elsewhere

## Architecture

| File | Responsibility |
|---|---|
| `DraftAidApp.swift` | App entry point, no scenes (Settings only) |
| `AppDelegate.swift` | Activation policy (`.accessory`), wires hotkey → panel |
| `StatusBarController.swift` | Status bar item + borderless floating `NSPanel` |
| `GlobalHotkeyManager.swift` | Carbon `RegisterEventHotKey` for `Cmd+Shift+T` |
| `ContentView.swift` | Main UI: input bar, result, recent history, full history sheet |
| `CommandInput.swift` | `NSTextField` wrapper intercepting Tab / Enter / Esc |
| `ModeManager.swift` | `DraftMode` model + persistence (UserDefaults) |
| `ModeSettingsView.swift` | Mode list, add/edit/enable/reset |
| `APISettingsView.swift` | API key entry (masked) |
| `KeychainHelper.swift` | Keychain storage for the API key |
| `GeminiService.swift` | Gemini API client (user-selectable model, retry + fallback) |
| `LocalModelService.swift` | Apple Foundation Models on-device engine (default) |
| `LocalStorage.swift` | History persistence (`~/Library/Application Support/DraftAid/history.json`) |

## Requirements

- macOS 26+ (Apple Intelligence required for the on-device engine; cloud mode works without it)
- Xcode 26+

## Build & Run

```sh
xcodebuild -project DraftAid.xcodeproj -scheme DraftAid -configuration Debug build
```

Or open `DraftAid.xcodeproj` in Xcode and press `Cmd+R`.

> **Note:** App Sandbox is disabled (`ENABLE_APP_SANDBOX = NO`) because the Carbon global hotkey requires it. Do not re-enable it without replacing the hotkey implementation.

## How Processing Works

Each mode's prompt template is filled in with its output language and your text, then sent to Gemini:

```swift
let prompt = mode.promptTemplate
    .replacingOccurrences(of: "{{language}}", with: mode.outputLanguage)
    + "\n\nINPUT:\n\(text)\n\nOUTPUT:"
```

If no API key is set, the panel shows a hint instead of a result. Failed calls are shown as errors and are not saved to history.

## License

MIT
