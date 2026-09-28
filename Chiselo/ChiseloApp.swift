import AppKit
import Sparkle
import SwiftUI

@MainActor
final class ChiseloAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: EditorModel?
    private var terminationReplyPending = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationReplyPending else { return .terminateLater }
        guard let model, model.hasOpenDocument else { return .terminateNow }

        terminationReplyPending = true
        model.prepareForApplicationTermination { [weak self, weak sender] shouldTerminate in
            self?.terminationReplyPending = false
            sender?.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }
}

@main
struct ChiseloApp: App {
    @NSApplicationDelegateAdaptor(ChiseloAppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()
    private let updaterController: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }()

    var body: some Scene {
        Window("Chiselo", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
                .onAppear {
                    appDelegate.model = model
                }
                .onOpenURL { url in
                    model.openDroppedURLs([url])
                }
        }
        .defaultSize(width: 1280, height: 820)
        Settings {
            PreferencesView()
                .environmentObject(model)
        }
        .commands {
            CommandMenu("Chiselo") {
                Button("Check for Updates…") {
                    if let updaterController {
                        updaterController.checkForUpdates(nil)
                    } else {
                        showPackagedUpdaterNotice()
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .newItem) {
                Button("Open HTML or Project...") {
                    model.openDeck()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    model.saveDeck()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.hasOpenDocument)

                Button("Convert to Editable Version") {
                    model.freezeCurrentHTMLLayout()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument)

                Button("Export as HTML...") {
                    model.exportHTML()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument)

                Button("Export as PDF...") {
                    model.exportPDF()
                }
                .disabled(!model.hasOpenDocument)

                if model.workspaceMode == .advanced {
                    Button("Export as Editable HTML...") {
                        model.exportEditableHTML()
                    }
                    .disabled(!model.hasOpenDocument)

                    Button("Export as PPTX...") {
                        model.exportPPTX()
                    }
                    .disabled(!model.hasOpenDocument)
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    model.editorCommand("undo")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.hasOpenDocument || !model.canUndoEdit)
                .help(model.nextUndoLabel.map { "Undo: \($0)" } ?? "Nothing to undo")

                Button("Redo") {
                    model.editorCommand("redo")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument || !model.canRedoEdit)
                .help(model.nextRedoLabel.map { "Redo: \($0)" } ?? "Nothing to redo")
            }

            CommandGroup(after: .undoRedo) {
                Button("Duplicate Object") {
                    model.editorCommand("duplicate")
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!model.hasOpenDocument)

                Button("Delete Object") {
                    model.editorCommand("delete")
                }
                .disabled(!model.hasOpenDocument)
            }
        }
    }

    private func showPackagedUpdaterNotice() {
        let alert = NSAlert()
        alert.messageText = "Updates Are Unavailable in Debug Builds"
        alert.informativeText = "Sparkle update checks are enabled only in a packaged Chiselo.app. The installed application uses its appcast to detect new versions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
