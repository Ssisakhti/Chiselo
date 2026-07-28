import SwiftUI

@main
struct ChiseloApp: App {
    @StateObject private var model = EditorModel()

    var body: some Scene {
        Window("Chiselo", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
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

                Button("Export as Editable HTML...") {
                    model.exportEditableHTML()
                }
                .disabled(!model.hasOpenDocument)

                Button("Export as PDF...") {
                    model.exportPDF()
                }
                .disabled(!model.hasOpenDocument)

                Button("Export as PPTX...") {
                    model.exportPPTX()
                }
                .disabled(!model.hasOpenDocument)
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
}
