import SwiftUI

struct WorkspaceModePicker: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Picker("Workspace Mode", selection: modeBinding) {
            ForEach(EditorModel.WorkspaceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.iconName)
                    .tag(mode)
                    .help(mode.detail)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .help(model.workspaceMode.detail)
    }

    private var modeBinding: Binding<EditorModel.WorkspaceMode> {
        Binding {
            model.workspaceMode
        } set: { mode in
            model.setWorkspaceMode(mode)
        }
    }
}

struct HTMLViewportPicker: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Picker("Responsive Preview", selection: deviceBinding) {
            ForEach(EditorModel.HTMLPreviewDevice.allCases) { device in
                Image(systemName: device.iconName)
                    .tag(device)
                    .help(device.viewportWidth.map { "\(device.title) · \($0)px" } ?? "Use the page's original width")
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 126)
        .disabled(!model.hasOpenDocument || model.documentMode != "html")
        .help("Check desktop, tablet, and phone layouts at actual CSS viewport widths without changing the HTML")
    }

    private var deviceBinding: Binding<EditorModel.HTMLPreviewDevice> {
        Binding {
            model.htmlPreviewDevice
        } set: { device in
            model.setHTMLPreviewDevice(device)
        }
    }
}

struct HTMLZoomControls: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.setHTMLZoomPreset("actual")
            } label: {
                Image(systemName: "1.magnifyingglass")
                    .frame(width: 17, height: 17)
                    .accessibilityLabel("Show at 100%")
            }
            .help("Show at 100%. HTML does not scale automatically.")

            Button {
                model.setHTMLZoomPreset("fit-width")
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .frame(width: 17, height: 17)
                    .accessibilityLabel("Fit Width")
            }
            .help("Fit the editor width for this view only")
        }
        .buttonStyle(MaterialButtonStyle())
        .disabled(!model.hasOpenDocument || model.documentMode != "html")
    }
}

struct AdvancedWorkspaceMenu: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Menu {
            Section("Page Runtime") {
                ForEach(EditorModel.HTMLRuntimeMode.allCases) { mode in
                    Button {
                        model.setActiveHTMLRuntimeMode(mode)
                    } label: {
                        Label(
                            mode.title,
                            systemImage: model.activeHTMLRuntimeMode == mode ? "checkmark.circle.fill" : mode.iconName
                        )
                    }
                    .disabled(!model.hasOpenDocument || model.documentMode != "html")
                }
            }

            Section("Editor Background") {
                ForEach(EditorModel.EditorBackdrop.allCases) { backdrop in
                    Button {
                        model.setEditorBackdrop(backdrop)
                    } label: {
                        Label(
                            backdrop.title,
                            systemImage: model.editorBackdrop == backdrop ? "checkmark.circle.fill" : backdrop.iconName
                        )
                    }
                }
            }

            Divider()

            Button {
                model.revealSafetyFolder()
            } label: {
                Label("Open Version Folder", systemImage: "clock.arrow.circlepath")
            }
            .disabled(!model.canRevealSafetyFolder)

            Button {
                model.presentHistoryBrowser()
            } label: {
                Label("Restore a Previous Version", systemImage: "arrow.counterclockwise.circle")
            }
            .disabled(!model.canRevealSafetyFolder)
        } label: {
            Label("Page Options", systemImage: "slider.horizontal.3")
        }
        .menuStyle(.button)
        .buttonStyle(MaterialButtonStyle())
        .help("Runtime mode, editor background, and version history")
    }
}
