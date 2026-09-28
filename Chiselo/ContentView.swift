import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                AppToolbar()

                if !model.tabs.isEmpty {
                    BrowserTabBar()
                }

                ZStack {
                    HSplitView {
                        DocumentNavigator()
                            .frame(minWidth: 156, idealWidth: 190, maxWidth: 320)
                            .frame(maxHeight: .infinity)

                        WebEditorView()
                            .frame(minWidth: 720)
                            .frame(maxHeight: .infinity)

                        InspectorPanel()
                            .frame(minWidth: 238, idealWidth: 286, maxWidth: 430)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)

                    if !model.hasOpenDocument {
                        WelcomeStartView()
                            .transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.bottom, 12)

                StatusBar()
            }
            .background(AppGlassBackground())

            if model.isFileDropTargeted {
                DropOverlay()
                    .padding(28)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: fileDropTargetBinding) { providers in
            model.openDroppedFiles(from: providers)
        }
        .sheet(isPresented: exportPreflightBinding) {
            ExportPreflightPanel()
                .environmentObject(model)
        }
        .sheet(isPresented: historyBrowserBinding) {
            HistoryBrowserPanel()
                .environmentObject(model)
        }
    }

    private var fileDropTargetBinding: Binding<Bool> {
        Binding {
            model.isFileDropTargeted
        } set: { targeted in
            model.setFileDropTargeted(targeted)
        }
    }

    private var exportPreflightBinding: Binding<Bool> {
        Binding {
            model.isExportPreflightPresented
        } set: { isPresented in
            model.isExportPreflightPresented = isPresented
        }
    }

    private var historyBrowserBinding: Binding<Bool> {
        Binding {
            model.isHistoryBrowserPresented
        } set: { isPresented in
            model.isHistoryBrowserPresented = isPresented
        }
    }
}

private struct AppGlassBackground: View {
    var body: some View {
        ZStack {
            MaterialTheme.background

            LinearGradient(
                colors: [
                    MaterialTheme.surfaceFloating,
                    MaterialTheme.surfaceChrome,
                    MaterialTheme.canvasChromeEnd.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            MaterialTheme.surfaceStrong.opacity(0.36),
                            MaterialTheme.surfaceChrome.opacity(0.26),
                            MaterialTheme.glow.opacity(0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

private struct BrowserTabBar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.tabs) { tab in
                        BrowserTab(tab: tab, isActive: tab.id == model.activeTabID)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 7)
                .padding(.bottom, 5)
            }

            Spacer(minLength: 8)

            Label("Drop to Open", systemImage: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MaterialTheme.muted)
                .padding(.trailing, 14)
                .help("Drop an HTML file anywhere in the window")

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MaterialTheme.muted.opacity(0.82))
                .padding(.trailing, 14)
                .help("Drag the divider to resize the side panels")
        }
        .frame(height: 44)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(MaterialTheme.surfaceChrome)
            }
        )
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(MaterialTheme.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct BrowserTab: View {
    @EnvironmentObject private var model: EditorModel

    var tab: EditorModel.EditorTab
    var isActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.activateTab(tab.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: tab.mode == "html" ? "safari" : "rectangle.on.rectangle")
                        .font(.system(size: 12, weight: .bold))
                    Text(tab.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if tab.hasUnsavedChanges {
                        Circle()
                            .fill(MaterialTheme.accentWarning)
                            .frame(width: 7, height: 7)
                            .accessibilityLabel("Has unsaved changes")
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isDocumentOperationInProgress)

            Button {
                model.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(model.isDocumentOperationInProgress)
            .help("Close tab")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(width: 214, height: 32)
        .foregroundStyle(isActive ? MaterialTheme.ink : MaterialTheme.muted)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isActive ? MaterialTheme.surfaceFloating : MaterialTheme.surfaceChrome)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isActive ? MaterialTheme.primary.opacity(0.30) : MaterialTheme.hairline.opacity(0.76), lineWidth: 1)
        )
        .shadow(color: isActive ? MaterialTheme.shadow.opacity(0.12) : .clear, radius: 8, x: 0, y: 2)
    }
}

private struct DropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MaterialTheme.primary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MaterialTheme.primary.opacity(0.58), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            )
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(MaterialTheme.primary)
                    Text("Drop in an HTML file to open it in a new tab")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("HTML / Chiselo project file")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(MaterialTheme.primaryDark)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                        .fill(.regularMaterial)
                        .shadow(color: MaterialTheme.shadow.opacity(0.22), radius: 16, x: 0, y: 6)
                )
            )
            .allowsHitTesting(false)
    }
}

private struct WelcomeStartView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MaterialTheme.primary)

            VStack(spacing: 7) {
                Text("Open a project to start")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(MaterialTheme.ink)

                Text("Open an HTML file or Chiselo project, or drop a file into the window.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .multilineTextAlignment(.center)
            }

            Button {
                model.openDeck()
            } label: {
                Label("Open Project", systemImage: "folder")
            }
            .buttonStyle(MaterialButtonStyle(filled: true))
            .keyboardShortcut("o", modifiers: .command)

            VStack(spacing: 6) {
                Text("Supports HTML, HTM, XHTML, and Chiselo project files")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(MaterialTheme.primaryDark)
            }
        }
        .padding(34)
        .frame(maxWidth: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel))
        .background(MaterialTheme.surfaceFloating, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                .stroke(MaterialTheme.hairline.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.12), radius: 24, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.22))
        )
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Form {
            Picker("Editor Backdrop", selection: backgroundBinding) {
                ForEach(EditorModel.EditorBackdrop.allCases) { backdrop in
                    Label(backdrop.title, systemImage: backdrop.iconName)
                        .tag(backdrop)
                }
            }
            .pickerStyle(.segmented)

            Text("The backdrop affects only the editing workspace. It is never written into exported HTML, PDF, or PPTX.")
                .font(.caption)
                .foregroundStyle(MaterialTheme.muted)
        }
        .padding(22)
        .frame(width: 420)
    }

    private var backgroundBinding: Binding<EditorModel.EditorBackdrop> {
        Binding {
            model.editorBackdrop
        } set: { value in
            model.setEditorBackdrop(value)
        }
    }
}

private extension EditorModel {
    var deckAspectRatio: Double {
        guard let canvas = deck?.canvas, canvas.height > 0 else { return 16.0 / 9.0 }
        return canvas.width / canvas.height
    }
}

private struct AppToolbar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chiselo")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(MaterialTheme.ink)
                Text("HTML Refine · Delivery Preflight")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(MaterialTheme.primary)
            }
            .frame(width: 150, alignment: .leading)

            ToolbarCommandGroup {
                ToolbarActionButton(title: "Open", icon: "folder") {
                    model.openDeck()
                }
                .help("Open an HTML, HTM, XHTML, or Chiselo project file")

                ToolbarActionButton(title: "Save", icon: "square.and.arrow.down") {
                    model.saveDeck()
                }
                .disabled(!model.hasOpenDocument)
                .help("Save the current file, writing a version snapshot before overwriting")

            }

            MaterialDivider()

            ToolbarActionButton(title: "Convert to Editable", icon: "viewfinder") {
                model.freezeCurrentHTMLLayout()
            }
            .disabled(!model.hasOpenDocument)
            .help("Capture the current rendering as a stable editable version with draggable objects, editable text, and replaceable images")

            MaterialDivider()

            ToolbarCommandGroup {
                ToolbarIconButton(icon: "arrow.uturn.backward", title: "Undo") {
                    model.editorCommand("undo")
                }
                .disabled(!model.hasOpenDocument || !model.canUndoEdit)
                .help(model.nextUndoLabel.map { "Undo: \($0)" } ?? "Nothing to undo")

                ToolbarIconButton(icon: "arrow.uturn.forward", title: "Redo") {
                    model.editorCommand("redo")
                }
                .disabled(!model.hasOpenDocument || !model.canRedoEdit)
                .help(model.nextRedoLabel.map { "Redo: \($0)" } ?? "Nothing to redo")
            }

            MaterialDivider()

            ExportMenu()

            HTMLViewportPicker()
            HTMLZoomControls()

            if model.workspaceMode == .advanced {
                AdvancedWorkspaceMenu()
            }

            WorkspaceModePicker()

            Spacer()

            HStack(spacing: 6) {
                Text(modeBadgeTitle)
                    .foregroundStyle(MaterialTheme.primaryDark)
                if let buildLabel {
                    Text(buildLabel)
                        .foregroundStyle(MaterialTheme.muted)
                }
            }
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(MaterialTheme.surfaceTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(MaterialTheme.separator, lineWidth: 1)
            )
            .help(buildHelp)
        }
        .buttonStyle(MaterialButtonStyle())
        .padding(.horizontal, MaterialTheme.panelPadding)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(MaterialTheme.surfaceChrome)
            }
            .shadow(color: MaterialTheme.shadow.opacity(0.10), radius: 12, x: 0, y: 2)
        )
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(MaterialTheme.separator).frame(height: 1), alignment: .bottom)
    }

    private var modeBadgeTitle: String {
        guard model.hasOpenDocument else { return "Ready to start" }
        return model.documentMode == "html" ? "Page Refine" : "Canvas Refine"
    }

    private var buildLabel: String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return nil }
        let fingerprint = (Bundle.main.infoDictionary?["ChiseloBuildFingerprint"] as? String)?.prefix(7)
        if let fingerprint, !fingerprint.isEmpty {
            return "v\(version) · \(fingerprint)"
        }
        return "v\(version)"
    }

    private var buildHelp: String {
        let mode = model.documentMode == "html" ? "Edit the current HTML page or document" : "Edit the current content on a fixed canvas"
        let timestamp = Bundle.main.infoDictionary?["ChiseloBuildTimestamp"] as? String
        if let buildLabel, let timestamp {
            return "\(mode). Current build: \(buildLabel), \(timestamp)"
        }
        return mode
    }
}

private struct ToolbarCommandGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
        }
    }
}

private struct ToolbarActionButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
    }
}

private struct ToolbarIconButton: View {
    var icon: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 17, height: 17)
                .accessibilityLabel(title)
        }
    }
}

private struct ExportMenu: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Menu {
            Button {
                model.presentExportPreflight()
            } label: {
                ExportMenuItemLabel(
                    title: "Export Preflight",
                    subtitle: preflightSubtitle,
                    icon: preflightIcon
                )
            }

            Divider()

            Button {
                model.exportHTML()
            } label: {
                ExportMenuItemLabel(
                    title: "Export HTML",
                    subtitle: "Keeps the source clean for further editing",
                    icon: "doc.text"
                )
            }

            if model.workspaceMode == .advanced {
                Button {
                    model.exportEditableHTML()
                } label: {
                    ExportMenuItemLabel(
                        title: "Editable HTML",
                        subtitle: "Edit text directly in the browser",
                        icon: "pencil.and.outline"
                    )
                }
            }

            Divider()

            Button {
                model.exportPDF()
            } label: {
                ExportMenuItemLabel(
                    title: "High-Fidelity PDF",
                    subtitle: "Paginated from the browser rendering",
                    icon: "doc.richtext"
                )
            }

            if model.workspaceMode == .advanced {
                Button {
                    model.exportPPTX()
                } label: {
                    ExportMenuItemLabel(
                        title: "Editable PPTX",
                        subtitle: "Deliver as an editable Office format",
                        icon: "rectangle.on.rectangle.angled"
                    )
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .buttonStyle(MaterialButtonStyle(filled: true))
        .disabled(!model.hasOpenDocument)
        .help(model.workspaceMode == .advanced ? "Export HTML, PDF, or editable PPTX" : "Export HTML or a high-fidelity PDF")
    }

    private var preflightSubtitle: String {
        guard model.documentMode == "html" else { return "Check the page, objects, and export format" }
        return model.workspaceMode == .advanced
            ? model.htmlDiagnostics.preflightSummary
            : model.htmlDiagnostics.ordinaryPreflightSummary
    }

    private var preflightIcon: String {
        guard model.documentMode == "html" else { return "checklist" }
        return model.workspaceMode == .advanced
            ? model.htmlDiagnostics.preflightIcon
            : model.htmlDiagnostics.ordinaryPreflightIcon
    }
}

private struct ExportMenuItemLabel: View {
    var title: String
    var subtitle: String
    var icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
        }
    }
}

private struct ExportPreflightPanel: View {
    @EnvironmentObject private var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: preflightHeaderIcon)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(headerColor)
                    .frame(width: 42, height: 42)
                    .background(headerColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Preflight")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer()

                Button {
                    model.refreshHTMLDiagnostics()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(MaterialButtonStyle())
                .disabled(model.documentMode != "html")
            }
            .padding(20)
            .background(MaterialTheme.surfaceStrong)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.documentMode == "html" {
                        htmlPreflightContent
                    } else {
                        deckPreflightContent
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 10) {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(MaterialButtonStyle())

                Spacer()

                Button {
                    closeThen { model.exportHTML() }
                } label: {
                    Label("Export HTML", systemImage: "doc.text")
                }
                .buttonStyle(MaterialButtonStyle())

                Button {
                    closeThen { model.exportPDF() }
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
                .buttonStyle(MaterialButtonStyle(filled: model.workspaceMode == .ordinary))

                if model.workspaceMode == .advanced {
                    Button {
                        closeThen { model.exportPPTX() }
                    } label: {
                        Label("Export PPTX", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .buttonStyle(MaterialButtonStyle(filled: true))
                }
            }
            .padding(16)
            .background(MaterialTheme.surfaceStrong)
        }
        .frame(width: 720, height: 680)
    }

    private var htmlPreflightContent: some View {
        let diagnostics = model.htmlDiagnostics

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: preflightScoreColumns, spacing: 12) {
                ExportTargetScoreCard(
                    title: "HTML",
                    subtitle: "Source cleanliness \(diagnostics.sourceCleanlinessPercent)%",
                    score: diagnostics.htmlReadinessScore,
                    icon: "doc.text",
                    detail: diagnostics.sourceCleanlinessDetail,
                    color: scoreColor(diagnostics.htmlReadinessScore)
                )

                ExportTargetScoreCard(
                    title: "PDF",
                    subtitle: "High-fidelity rendering",
                    score: diagnostics.pdfFidelityScore,
                    icon: "doc.richtext",
                    detail: "PDF follows the browser rendering. Focus on broken links, out-of-bounds objects, and text overflow.",
                    color: scoreColor(diagnostics.pdfFidelityScore)
                )

                if model.workspaceMode == .advanced {
                    ExportTargetScoreCard(
                        title: "PPTX",
                        subtitle: "Editability \(diagnostics.pptxEditabilityScore)%",
                        score: diagnostics.pptxEditabilityScore,
                        icon: "rectangle.on.rectangle.angled",
                        detail: diagnostics.pptxRiskSummary,
                        color: scoreColor(diagnostics.pptxEditabilityScore)
                    )
                }
            }

            PreflightRecommendationCard(
                diagnostics: diagnostics,
                includesPPTX: model.workspaceMode == .advanced
            )
            if (diagnostics.visualChangeCount ?? 0) > 0 {
                VisualChangeReviewCard(
                    diagnostics: diagnostics,
                    snapshots: model.htmlVisualSnapshotPair,
                    isCapturingSnapshot: model.isCapturingHTMLVisualSnapshot,
                    onRefreshSnapshot: {
                        model.refreshHTMLVisualReviewSnapshot()
                    },
                    onSelectTarget: { elementId in
                        dismiss()
                        model.selectHTMLNode(id: elementId)
                    },
                    onRevertChange: { changeKey in
                        model.revertHTMLVisualChange(changeKey: changeKey)
                    }
                )
            }
            if (diagnostics.responsiveChangeCount ?? 0) > 0 {
                ResponsiveChangeReviewCard(diagnostics: diagnostics) { elementId in
                    dismiss()
                    model.selectHTMLNode(id: elementId)
                }
            }
            if model.workspaceMode == .advanced, diagnostics.sourcePollutionReviewCount > 0 {
                SourceWritebackReviewCard(
                    diagnostics: diagnostics,
                    onSelectTarget: { elementId in
                        dismiss()
                        model.selectHTMLNode(id: elementId)
                    },
                    onRevertChange: { changeKey in
                        model.revertHTMLVisualChange(changeKey: changeKey)
                    }
                )
            }
            if model.workspaceMode == .advanced {
                PPTXMappingReportCard(diagnostics: diagnostics) { elementId in
                    dismiss()
                    model.selectHTMLNode(id: elementId)
                }
                if diagnostics.hasPPTXRepairActions {
                    PPTXRepairActionCard(
                        diagnostics: diagnostics,
                        onSelectTarget: { elementId in
                            dismiss()
                            model.selectHTMLNode(id: elementId)
                        },
                        onConvertEditable: {
                            closeThen { model.freezeCurrentHTMLLayout() }
                        },
                        onExportPDF: {
                            closeThen { model.exportPDF() }
                        }
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Issue Locator")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)

                if !visiblePreflightIssues.isEmpty {
                    ForEach(visiblePreflightIssues.prefix(10)) { issue in
                        DeliveryIssueRow(issue: issue) {
                            if let elementId = issue.elementId {
                                dismiss()
                                model.selectHTMLNode(id: elementId)
                            }
                        } relatedAction: {
                            if let elementId = issue.relatedElementId {
                                dismiss()
                                model.selectHTMLNode(id: elementId)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(successColor)
                        Text("No delivery-blocking issues found.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                    }
                    .padding(12)
                    .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                }
            }

            if model.workspaceMode == .advanced {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PPTX Review Notes")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)

                    PreflightNoteRow(icon: "rectangle.2.swap", title: "Visual Changes", detail: (diagnostics.visualChangeCount ?? 0) > 0 ? "\(diagnostics.visualChangeCount ?? 0) objects changed since opening. Review each item before export." : "No clear object-level changes were detected since opening.")
                    PreflightNoteRow(icon: "rectangle.split.3x1", title: "Responsive Layout", detail: diagnostics.responsiveReviewDetail)
                    PreflightNoteRow(icon: "tablecells", title: "Tables", detail: diagnostics.spanTableCount > 0 ? "Merged cells reduce the stability of PPTX object mapping." : "Review rows, columns, and text boxes in standard tables after export.")
                    PreflightNoteRow(icon: "scribble.variable", title: "Vector/SVG", detail: diagnostics.svgCount > 0 ? "SVG or complex vectors can become shapes or images. Review their editability." : "No clear SVG risk was detected.")
                    PreflightNoteRow(icon: "camera.filters", title: "Visual Effects", detail: (diagnostics.pptxEffectRiskCount ?? 0) > 0 ? "\(diagnostics.pptxEffectRiskCount ?? 0) complex CSS effects require review after PPTX export." : "No clear complex CSS effect risk was detected.")
                    PreflightNoteRow(icon: "square.stack.3d.up", title: "Layers", detail: (diagnostics.overlapCount ?? 0) > 0 ? "Review the layer order of overlapping objects after PPTX export." : "No clear overlap risk was detected.")
                }
            }
        }
    }

    private var deckPreflightContent: some View {
        let editableSummary = model.deck?.editableVersionSummary

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: preflightScoreColumns, spacing: 12) {
                ExportTargetScoreCard(
                    title: "HTML",
                    subtitle: "Canvas export",
                    score: 96,
                    icon: "doc.text",
                    detail: "The content is already a fixed canvas, so HTML export risk is low.",
                    color: scoreColor(96)
                )
                ExportTargetScoreCard(
                    title: "PDF",
                    subtitle: "Page rendering",
                    score: 96,
                    icon: "doc.richtext",
                    detail: "PDF renders at page size, which suits high-fidelity delivery.",
                    color: scoreColor(96)
                )
                if model.workspaceMode == .advanced {
                    ExportTargetScoreCard(
                        title: "PPTX",
                        subtitle: editableSummary.map { "Editability \($0.pptxEditabilityScore)%" } ?? "Editable objects",
                        score: editableSummary?.pptxEditabilityScore ?? 90,
                        icon: "rectangle.on.rectangle.angled",
                        detail: editableSummary?.pptxDetail ?? "Text, images, and shapes are kept editable when possible.",
                        color: scoreColor(editableSummary?.pptxEditabilityScore ?? 90)
                    )
                }
            }

            if let editableSummary {
                EditableVersionQualityCard(summary: editableSummary, isExpanded: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Page Structure")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                PreflightNoteRow(icon: "rectangle.on.rectangle", title: "Pages", detail: "\(model.documentStats.pageCount ?? 0) page(s)")
                PreflightNoteRow(icon: "square.grid.2x2", title: "Objects", detail: "\(model.documentStats.objectCount ?? 0) object(s)")
                PreflightNoteRow(icon: "photo", title: "Images", detail: "\(model.documentStats.imageCount ?? 0) image(s)")
            }
        }
    }

    private var headerSubtitle: String {
        if model.documentMode == "html" {
            return model.workspaceMode == .advanced
                ? model.htmlDiagnostics.preflightSummary
                : model.htmlDiagnostics.ordinaryPreflightSummary
        }
        return model.workspaceMode == .advanced ? "The fixed canvas can export HTML, PDF, and PPTX" : "The fixed canvas can export HTML and PDF"
    }

    private var preflightHeaderIcon: String {
        guard model.documentMode == "html" else { return "checklist" }
        return model.workspaceMode == .advanced
            ? model.htmlDiagnostics.preflightIcon
            : model.htmlDiagnostics.ordinaryPreflightIcon
    }

    private var headerColor: Color {
        if model.documentMode == "html" {
            let diagnostics = model.htmlDiagnostics
            let score = model.workspaceMode == .advanced
                ? diagnostics.overallExportScore
                : min(diagnostics.htmlReadinessScore, diagnostics.pdfFidelityScore)
            return scoreColor(score)
        }
        return successColor
    }

    private var preflightScoreColumns: [GridItem] {
        let count = model.workspaceMode == .advanced ? 3 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    private var visiblePreflightIssues: [HTMLDiagnosticIssue] {
        let issues = model.htmlDiagnostics.issues ?? []
        guard model.workspaceMode == .ordinary else { return issues }
        let advancedOnlyKinds: Set<String> = [
            "span-table",
            "pptx-effect-risk",
            "source-pollution-review",
            "stylesheet-rule-writeback",
            "stylesheet-edit-review"
        ]
        return issues.filter { !advancedOnlyKinds.contains($0.kind) }
    }

    private var successColor: Color {
        MaterialTheme.accentSuccess
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return successColor }
        if score >= 65 { return MaterialTheme.accentWarning }
        return MaterialTheme.accentDanger
    }

    private func closeThen(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.async {
            action()
        }
    }
}

private struct ExportTargetScoreCard: View {
    var title: String
    var subtitle: String
    var score: Int
    var icon: String
    var detail: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            Text("\(score)%")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(color)

            Text(detail)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct PreflightRecommendationCard: View {
    var diagnostics: HTMLDiagnostics
    var includesPPTX: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Guidance")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { _, recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: recommendation.icon)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(recommendation.color)
                        .frame(width: 18, height: 18)
                    Text(recommendation.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
    }

    private var recommendations: [(icon: String, text: String, color: Color)] {
        var items: [(String, String, Color)] = []
        if diagnostics.blockingExportRiskCount > 0 {
            items.append(("exclamationmark.triangle.fill", "Resolve the red issues before exporting a final version. Broken links, text overflow, and out-of-bounds objects directly affect delivery quality.", MaterialTheme.accentDanger))
        } else {
            items.append(("checkmark.seal.fill", "HTML and PDF are ready for export review. Open and review important exported files.", MaterialTheme.accentSuccess))
        }

        if includesPPTX {
            if diagnostics.pptxReviewRiskCount > 0 {
                items.append(("rectangle.on.rectangle.angled", "For editable PPTX export, review tables, SVG content, complex visual effects, overlapping objects, and merged cells.", MaterialTheme.accentWarning))
            } else {
                items.append(("rectangle.on.rectangle.angled", "PPTX editability risk is low. Review text boxes, images, and object layers after export.", MaterialTheme.accentSuccess))
            }
        }

        if (diagnostics.visualChangeCount ?? 0) > 0 {
            items.append(("rectangle.2.swap", "Object-level visual changes were detected. Confirm each change before export.", MaterialTheme.accentWarning))
        }

        if diagnostics.runtimeCompatibilityRiskCount > 0 {
            items.append(("viewfinder", "Script-rendered content, embedded pages, and canvas content cannot always become standard objects. Convert to an editable version before precise editing when you need a stable deliverable.", MaterialTheme.accentWarning))
        }
        return items
    }
}

private struct VisualChangeReviewCard: View {
    var diagnostics: HTMLDiagnostics
    var snapshots: HTMLVisualSnapshotPair
    var isCapturingSnapshot: Bool
    var onRefreshSnapshot: () -> Void
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    @State private var targetIndex = 0
    @State private var selectedFilter: VisualChangeFilter = .all

    var body: some View {
        let changeCount = diagnostics.visualChangeCount ?? 0
        let previewItems = diagnostics.visualChangePreviewItems
        let filteredItems = selectedFilter.items(from: previewItems)
        let targetIds = diagnostics.visualChangeTargetIds(for: selectedFilter)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(warningColor)
                    .frame(width: 22, height: 22)
                    .background(warningColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Visual Change Review")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(visualChangeSubtitle(changeCount: changeCount, targetCount: targetIds.count))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(warningColor)
                }

                Spacer()
            }

            Text("Confirm each change before exporting so text, images, size, position, and key styles are not altered by accident.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !previewItems.isEmpty {
                VisualChangeFilterPicker(
                    selection: $selectedFilter,
                    items: previewItems,
                    color: warningColor
                )
            }

            VisualSnapshotComparison(
                snapshots: snapshots,
                isCapturingSnapshot: isCapturingSnapshot,
                color: warningColor,
                onRefresh: onRefreshSnapshot
            )

            if !previewItems.isEmpty {
                if filteredItems.isEmpty {
                    VisualChangeEmptyFilter(filter: selectedFilter)
                } else {
                    VisualChangeMap(
                        items: filteredItems,
                        totalCount: selectedFilter == .all ? changeCount : filteredItems.count,
                        canvasWidth: diagnostics.visualChangePreviewCanvasWidth,
                        canvasHeight: diagnostics.visualChangePreviewCanvasHeight,
                        color: warningColor,
                        onSelectTarget: onSelectTarget
                    )

                    VisualChangePreviewList(
                        items: Array(filteredItems.prefix(6)),
                        totalCount: selectedFilter == .all ? changeCount : filteredItems.count,
                        previewCount: filteredItems.count,
                        color: warningColor,
                        onSelectTarget: onSelectTarget,
                        onRevertChange: onRevertChange
                    )
                }
            }

            if !targetIds.isEmpty {
                PPTXTargetNavigator(
                    title: selectedFilter == .all ? "Visual Changes" : selectedFilter.title,
                    icon: "rectangle.2.swap",
                    count: targetIds.count,
                    targetIds: targetIds,
                    color: warningColor,
                    index: $targetIndex,
                    onSelectTarget: onSelectTarget
                )
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)
                    Text("These changes come mostly from deleted or non-locatable objects. Review them against the canvas and Version History.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(warningColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var warningColor: Color {
        MaterialTheme.accentWarning
    }

    private func visualChangeSubtitle(changeCount: Int, targetCount: Int) -> String {
        let revertableCount = diagnostics.revertableVisualChangeCount ?? 0
        let targetPart = targetCount == 0 ? "includes non-locatable objects" : "\(targetCount) locatable"
        if revertableCount > 0 {
            return "\(changeCount) change(s), \(targetPart), \(revertableCount) revertable in one step"
        }
        return "\(changeCount) change(s), \(targetPart)"
    }
}

private struct ResponsiveChangeReviewCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: (String) -> Void

    @State private var targetIndex = 0

    private let color = MaterialTheme.accentWarning

    var body: some View {
        let items = diagnostics.responsiveChangePreviewItems
        let targetIds = diagnostics.responsiveChangeTargetIds
        let count = diagnostics.responsiveChangeCount ?? targetIds.count

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Responsive Change Review")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("\(count) changed object(s) affected by responsive layout")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }

                Spacer(minLength: 0)
            }

            Text(diagnostics.responsiveReviewDetail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !diagnostics.responsiveReviewWidthText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "ruler")
                        .font(.system(size: 10, weight: .heavy))
                    Text(diagnostics.responsiveReviewWidthText)
                        .font(.system(size: 10, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items.prefix(5)) { item in
                        Button {
                            if let elementId = item.elementId {
                                onSelectTarget(elementId)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: responsiveIcon(for: item))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(color)
                                    .frame(width: 18, height: 18)
                                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundStyle(MaterialTheme.ink)
                                        .lineLimit(1)
                                    Text(item.detail ?? item.kindDisplay)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(MaterialTheme.muted)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                    if let responsiveHint = responsiveHint(for: item) {
                                        Text(responsiveHint)
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundStyle(color)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                }

                                Spacer(minLength: 0)

                                if item.elementId != nil {
                                    Image(systemName: "scope")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(MaterialTheme.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(item.elementId == nil)
                    }

                    if count > items.prefix(5).count {
                        Text("The remaining \(count - items.prefix(5).count) responsive change(s) can be reviewed with the locator.")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                    }
                }
                .padding(10)
                .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }

            if !targetIds.isEmpty {
                PPTXTargetNavigator(
                    title: "Responsive Changes",
                    icon: "rectangle.split.3x1",
                    count: count,
                    targetIds: targetIds,
                    color: color,
                    index: $targetIndex,
                    onSelectTarget: onSelectTarget
                )
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func responsiveIcon(for item: HTMLVisualChangeItem) -> String {
        if item.kind.contains("文字") { return "textformat" }
        if item.kind.contains("图片") { return "photo" }
        if item.kind.contains("位置") || item.kind.contains("尺寸") { return "arrow.up.left.and.arrow.down.right" }
        if item.kind.contains("样式") { return "paintbrush" }
        return "scope"
    }

    private func responsiveHint(for item: HTMLVisualChangeItem) -> String? {
        var parts: [String] = []
        if let layoutKind = item.responsiveLayoutKind?.trimmingCharacters(in: .whitespacesAndNewlines), !layoutKind.isEmpty {
            parts.append(layoutKind)
        }
        let widths = (item.responsiveReviewWidths ?? []).prefix(4)
        if !widths.isEmpty {
            parts.append("widths \(widths.map { "\($0)" }.joined(separator: "/"))px")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct SourceWritebackReviewCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    @State private var targetIndex = 0

    private let color = MaterialTheme.accentWarning

    var body: some View {
        let inlineItems = diagnostics.inlineStyleChangeItems
        let ruleItems = diagnostics.stylesheetRuleChangeItems
        let ruleCount = diagnostics.stylesheetRuleWritebackCount ?? ruleItems.count
        let externalAffectedChanges = diagnostics.externalStylesheetAffectedChangeCount ?? 0
        let ruleTargets = Array(diagnostics.stylesheetRuleWritebackTargets.prefix(6))
        let targetIds = diagnostics.sourceWritebackTargetIds

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "curlybraces.square")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Source Review")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(sourceWritebackSubtitle(inlineCount: inlineItems.count, ruleCount: ruleCount, externalAffectedChanges: externalAffectedChanges))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }

                Spacer(minLength: 0)
            }

            Text(diagnostics.sourcePollutionReviewDetail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            let previewItems = Array((inlineItems + ruleItems).prefix(6))
            if !previewItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(previewItems) { item in
                        SourceWritebackRow(
                            item: item,
                            color: color,
                            onSelectTarget: onSelectTarget,
                            onRevertChange: onRevertChange
                        )
                    }
                }
                .padding(10)
                .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }

            if !ruleTargets.isEmpty {
                SourceWritebackSelectorList(selectors: ruleTargets, totalCount: ruleCount, color: color)
            }

            if !targetIds.isEmpty {
                PPTXTargetNavigator(
                    title: "Source Review",
                    icon: "curlybraces.square",
                    count: inlineItems.count + ruleCount + externalAffectedChanges,
                    targetIds: targetIds,
                    color: color,
                    index: $targetIndex,
                    onSelectTarget: onSelectTarget
                )
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func sourceWritebackSubtitle(inlineCount: Int, ruleCount: Int, externalAffectedChanges: Int) -> String {
        var parts: [String] = []
        if ruleCount > 0 { parts.append("\(ruleCount) write(s) to CSS rules") }
        if inlineCount > 0 { parts.append("\(inlineCount) write(s) to inline style") }
        if externalAffectedChanges > 0 { parts.append("\(externalAffectedChanges) needing external CSS review") }
        return parts.isEmpty ? "No object-level source risk detected" : parts.joined(separator: ", ")
    }
}

private struct SourceWritebackSelectorList: View {
    var selectors: [String]
    var totalCount: Int
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "curlybraces")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(MaterialTheme.accentSuccess)
                .frame(width: 18, height: 18)
                .background(MaterialTheme.accentSuccess.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                Text("CSS Rules")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(selectorDetail)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var selectorDetail: String {
        let visible = selectors.joined(separator: ", ")
        let hidden = max(0, totalCount - selectors.count)
        return hidden > 0 ? "\(visible), plus \(hidden) more rule(s)" : visible
    }
}

private struct SourceWritebackRow: View {
    var item: HTMLVisualChangeItem
    var color: Color
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                if let elementId = item.elementId {
                    onSelectTarget(elementId)
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.writebackKind == "stylesheet-rule" ? "curlybraces" : "paintbrush.pointed")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(iconColor)
                        .frame(width: 18, height: 18)
                        .background(iconColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(MaterialTheme.ink)
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 0)

                    if item.elementId != nil {
                        Image(systemName: "scope")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(MaterialTheme.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.elementId == nil)

            if let changeKey = item.changeKey, item.canRevert == true {
                Button {
                    onRevertChange(changeKey)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .heavy))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(iconColor)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .help("Revert this source-related change")
            }
        }
    }

    private var detail: String {
        let prefix = writebackPrefix
        if let afterValue = item.afterValue, !afterValue.isEmpty {
            return "\(prefix): \(afterValue)"
        }
        return "\(prefix): \(item.detail ?? item.kindDisplay)"
    }

    private var writebackPrefix: String {
        if item.writebackKind == "stylesheet-rule" {
            let target = (item.writebackTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return target.isEmpty ? "CSS rule" : "CSS rule \(target)"
        }
        if item.writebackKind == "inline-style" {
            return "inline style"
        }
        return item.writebackLabel ?? "Source"
    }

    private var iconColor: Color {
        item.writebackKind == "stylesheet-rule" ? MaterialTheme.accentSuccess : color
    }
}

private struct VisualChangeFilterPicker: View {
    @Binding var selection: VisualChangeFilter
    var items: [HTMLVisualChangeItem]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Change Type", selection: $selection) {
                ForEach(VisualChangeFilter.allCases) { filter in
                    Text("\(filter.title) \(count(for: filter))")
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Text(selection == .all ? "Showing all object-level changes." : "Showing only \(selection.title) changes.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
        }
        .padding(8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private func count(for filter: VisualChangeFilter) -> Int {
        filter.items(from: items).count
    }
}

private struct VisualChangeEmptyFilter: View {
    var filter: VisualChangeFilter

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(MaterialTheme.muted)
            Text("No \(filter.title) changes right now.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct VisualSnapshotComparison: View {
    var snapshots: HTMLVisualSnapshotPair
    var isCapturingSnapshot: Bool
    var color: Color
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Before/After Screenshots")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer(minLength: 0)

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .heavy))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(color)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .disabled(isCapturingSnapshot)
                .help("Refresh the current screenshot")
            }

            if snapshots.hasImages {
                LazyVGrid(columns: snapshotColumns, spacing: 8) {
                    VisualSnapshotTile(title: "At open", image: snapshots.baseline, color: color)
                    VisualSnapshotTile(title: "Current", image: snapshots.current, color: color)
                    VisualSnapshotTile(title: "Difference heatmap", image: snapshots.diff?.heatmap, color: diffColor)
                }

                if let diff = snapshots.diff {
                    HStack(spacing: 8) {
                        VisualDiffMetric(
                            value: percentText(diff.changedPixelRatio),
                            label: "Changed pixels",
                            icon: "square.grid.3x3.fill",
                            color: diffColor
                        )
                        VisualDiffMetric(
                            value: percentText(diff.averageDelta),
                            label: "Average difference",
                            icon: "waveform.path.ecg",
                            color: diffColor
                        )
                        VisualDiffMetric(
                            value: percentText(diff.maxDelta),
                            label: "Peak difference",
                            icon: "exclamationmark.triangle.fill",
                            color: diffColor
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(isCapturingSnapshot ? 1 : 0)
                    Text(isCapturingSnapshot ? "Capturing the current view..." : "No screenshot yet. Click Refresh to capture the current view.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var subtitle: String {
        if isCapturingSnapshot { return "Refreshing the current view" }
        if let diff = snapshots.diff {
            return diff.hasMeaningfulChange ? "Difference heatmap generated" : "Screenshot difference is very slight"
        }
        if snapshots.baseline != nil && snapshots.current != nil { return "View at open vs. current" }
        if snapshots.baseline != nil { return "Saved the view at open, waiting for a current screenshot" }
        if snapshots.current != nil { return "Current view captured" }
        return "For manual comparison before export"
    }

    private var snapshotColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    private var diffColor: Color {
        guard let diff = snapshots.diff else { return color }
        if diff.changedPixelRatio >= 0.12 || diff.averageDelta >= 0.055 {
            return MaterialTheme.accentDanger
        }
        if diff.hasMeaningfulChange {
            return color
        }
        return MaterialTheme.accentSuccess
    }

    private func percentText(_ value: Double) -> String {
        let percent = value * 100
        if percent < 0.1 && percent > 0 {
            return "<0.1%"
        }
        return "\(Int(percent.rounded()))%"
    }
}

private struct VisualSnapshotTile: View {
    var title: String
    var image: NSImage?
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(MaterialTheme.muted)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MaterialTheme.surfaceStrong)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(4)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .heavy))
                        Text("Not captured")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(MaterialTheme.muted)
                }
            }
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(image == nil ? 0.10 : 0.18), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VisualDiffMetric: View {
    var value: String
    var label: String
    var icon: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct VisualChangeMap: View {
    var items: [HTMLVisualChangeItem]
    var totalCount: Int
    var canvasWidth: Int
    var canvasHeight: Int
    var color: Color
    var onSelectTarget: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Visual Change Map")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(mapSubtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(MaterialTheme.surfaceStrong)
                    pageGrid
                    ForEach(items) { item in
                        heatZone(for: item, in: proxy.size)
                    }
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var pageGrid: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.72), MaterialTheme.surfaceTint.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Path { path in
                let step: CGFloat = 24
                let maxLine: CGFloat = 4000
                var position: CGFloat = step
                while position < maxLine {
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: maxLine))
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: maxLine, y: position))
                    position += step
                }
            }
            .stroke(MaterialTheme.primary.opacity(0.045), lineWidth: 1)
        }
    }

    private var mapSubtitle: String {
        if items.count < totalCount {
            return "Showing the first \(items.count) of \(totalCount) hotspots"
        }
        return "\(totalCount) hotspot(s)"
    }

    private var aspectRatio: CGFloat {
        let width = max(CGFloat(canvasWidth), 1)
        let height = max(CGFloat(canvasHeight), 1)
        return width / height
    }

    @ViewBuilder
    private func heatZone(for item: HTMLVisualChangeItem, in size: CGSize) -> some View {
        let rect = normalizedRect(for: item, in: size)
        let zone = RoundedRectangle(cornerRadius: 4)
            .fill(fillColor(for: item).opacity(item.elementId == nil ? 0.20 : 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(fillColor(for: item).opacity(item.elementId == nil ? 0.50 : 0.82), lineWidth: 1.4)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .help(item.elementId == nil ? "\(item.kindDisplay): \(item.label)" : "Locate: \(item.kindDisplay) \(item.label)")

        if let elementId = item.elementId {
            Button {
                onSelectTarget(elementId)
            } label: {
                zone
            }
            .buttonStyle(.plain)
        } else {
            zone
        }
    }

    private func normalizedRect(for item: HTMLVisualChangeItem, in size: CGSize) -> CGRect {
        let width = max(CGFloat(canvasWidth), 1)
        let height = max(CGFloat(canvasHeight), 1)
        let itemX = min(max(CGFloat(item.x), 0), width)
        let itemY = min(max(CGFloat(item.y), 0), height)
        let itemW = min(max(CGFloat(item.w), 1), width - itemX)
        let itemH = min(max(CGFloat(item.h), 1), height - itemY)
        let x = itemX / width * size.width
        let y = itemY / height * size.height
        let w = max(itemW / width * size.width, 5)
        let h = max(itemH / height * size.height, 5)
        return CGRect(
            x: min(max(x, 0), max(size.width - w, 0)),
            y: min(max(y, 0), max(size.height - h, 0)),
            width: min(w, size.width),
            height: min(h, size.height)
        )
    }

    private func fillColor(for item: HTMLVisualChangeItem) -> Color {
        if item.kind.contains("删除") { return MaterialTheme.accentDanger }
        if item.kind.contains("新增") { return MaterialTheme.accentSuccess }
        return color
    }
}

private struct VisualChangePreviewList: View {
    var items: [HTMLVisualChangeItem]
    var totalCount: Int
    var previewCount: Int
    var color: Color
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Change List")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
                if totalCount > items.count {
                    Text("First \(items.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }
            }

            ForEach(items) { item in
                VisualChangePreviewRow(item: item, color: color, onSelectTarget: onSelectTarget, onRevertChange: onRevertChange)
            }

            if totalCount > previewCount {
                Text("The remaining \(totalCount - previewCount) change(s) are not in the thumbnail preview. Use Step Through to review them.")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct VisualChangePreviewRow: View {
    var item: HTMLVisualChangeItem
    var color: Color
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(rowColor)
                    .frame(width: 18, height: 18)
                    .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label.isEmpty ? "Object" : item.label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                    Text("\(item.kindDisplay) · x \(item.x), y \(item.y), \(item.w) x \(item.h)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                actionBar
            }

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }

            if hasBeforeAfter {
                HStack(spacing: 6) {
                    VisualChangeValuePill(title: "At open", value: item.beforeValue, color: MaterialTheme.muted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)
                    VisualChangeValuePill(title: "Current", value: item.afterValue, color: rowColor)
                }
            } else if let reason = item.revertReason, !(item.canRevert ?? false) {
                Text(reason)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(rowColor.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 5) {
            if let changeKey = item.changeKey, item.canRevert == true {
                Button {
                    onRevertChange(changeKey)
                } label: {
                    Label("Revert", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(rowColor)
                .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .help("Revert only this visual change")
            }

            if let elementId = item.elementId {
                Button {
                    onSelectTarget(elementId)
                } label: {
                    Label("Locate", systemImage: "scope")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(rowColor)
                .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .help("Locate this change")
            } else {
                Text("Not locatable")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(MaterialTheme.muted)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var hasBeforeAfter: Bool {
        !(item.beforeValue ?? "").isEmpty || !(item.afterValue ?? "").isEmpty
    }

    private var icon: String {
        if item.kind.contains("删除") { return "minus.square" }
        if item.kind.contains("新增") { return "plus.square" }
        if item.kind.contains("位置") || item.kind.contains("尺寸") { return "arrow.up.left.and.arrow.down.right" }
        if item.kind.contains("文字") { return "textformat" }
        if item.kind.contains("样式") { return "paintpalette" }
        return "rectangle.2.swap"
    }

    private var rowColor: Color {
        if item.kind.contains("删除") { return MaterialTheme.accentDanger }
        if item.kind.contains("新增") { return MaterialTheme.accentSuccess }
        return color
    }
}

private struct VisualChangeValuePill: View {
    var title: String
    var value: String?
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(color)
            Text(displayValue)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }

    private var displayValue: String {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Empty" : text
    }
}

private struct PPTXMappingReportCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: ((String) -> Void)?

    @State private var textTargetIndex = 0
    @State private var imageTargetIndex = 0
    @State private var shapeTargetIndex = 0
    @State private var reviewTargetIndex = 0
    @State private var fallbackTargetIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(reportColor)
                    .frame(width: 22, height: 22)
                    .background(reportColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text("PPTX Editable Objects")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("\(diagnostics.pptxEditableEstimate)% estimated editable")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(reportColor)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MappingMetric(value: "\(diagnostics.pptxTextObjectCount ?? 0)", label: "Text", icon: "textformat", elementId: diagnostics.pptxTextElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxImageObjectCount ?? 0)", label: "Images", icon: "photo", elementId: diagnostics.pptxImageElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxShapeObjectCount ?? 0)", label: "Shapes", icon: "square.on.circle", elementId: diagnostics.pptxShapeElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxReviewObjectCount ?? 0)", label: "Needs review", icon: "checklist", elementId: diagnostics.pptxReviewElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxFallbackObjectCount ?? 0)", label: "Whole objects", icon: "rectangle.dashed", elementId: diagnostics.pptxFallbackElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxMappingTotalObjectCount)", label: "Total", icon: "square.grid.2x2")
            }

            if let onSelectTarget, hasTargetNavigation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step Through")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)

                    if diagnostics.pptxTextTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "Text",
                            icon: "textformat",
                            count: diagnostics.pptxTextObjectCount ?? 0,
                            targetIds: diagnostics.pptxTextTargetIds,
                            color: MaterialTheme.primary,
                            index: $textTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if diagnostics.pptxImageTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "Images",
                            icon: "photo",
                            count: diagnostics.pptxImageObjectCount ?? 0,
                            targetIds: diagnostics.pptxImageTargetIds,
                            color: MaterialTheme.primary,
                            index: $imageTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if diagnostics.pptxShapeTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "Shapes",
                            icon: "square.on.circle",
                            count: diagnostics.pptxShapeObjectCount ?? 0,
                            targetIds: diagnostics.pptxShapeTargetIds,
                            color: MaterialTheme.primary,
                            index: $shapeTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if !diagnostics.pptxReviewTargetIds.isEmpty {
                        PPTXTargetNavigator(
                            title: "Needs review",
                            icon: "checklist",
                            count: diagnostics.pptxReviewObjectCount ?? 0,
                            targetIds: diagnostics.pptxReviewTargetIds,
                            color: MaterialTheme.accentWarning,
                            index: $reviewTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if !diagnostics.pptxFallbackTargetIds.isEmpty {
                        PPTXTargetNavigator(
                            title: "Whole objects",
                            icon: "rectangle.dashed",
                            count: diagnostics.pptxFallbackObjectCount ?? 0,
                            targetIds: diagnostics.pptxFallbackTargetIds,
                            color: MaterialTheme.accentDanger,
                            index: $fallbackTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }
                }
                .padding(10)
                .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }

            Text(diagnostics.pptxMappingRecommendation)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(reportColor.opacity(0.20), lineWidth: 1)
        )
    }

    private var reportColor: Color {
        if diagnostics.pptxFallbackObjectCount ?? 0 > 0 { return MaterialTheme.accentDanger }
        if diagnostics.pptxReviewObjectCount ?? 0 > 0 { return MaterialTheme.accentWarning }
        return MaterialTheme.accentSuccess
    }

    private var hasTargetNavigation: Bool {
        diagnostics.pptxTextTargetIds.count > 1
            || diagnostics.pptxImageTargetIds.count > 1
            || diagnostics.pptxShapeTargetIds.count > 1
            || !diagnostics.pptxReviewTargetIds.isEmpty
            || !diagnostics.pptxFallbackTargetIds.isEmpty
    }
}

private struct MappingMetric: View {
    var value: String
    var label: String
    var icon: String
    var elementId: String?
    var action: ((String) -> Void)?

    var body: some View {
        Group {
            if let elementId, let action {
                Button {
                    action(elementId)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isActionable ? MaterialTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .help(isActionable ? "Click to locate the first \(label)" : "\(label) count")
    }

    private var content: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
    }

    private var isActionable: Bool {
        elementId != nil && action != nil
    }

    private var backgroundColor: Color {
        isActionable ? MaterialTheme.primary.opacity(0.10) : MaterialTheme.surfaceTint
    }
}

private struct PPTXTargetNavigator: View {
    var title: String
    var icon: String
    var count: Int
    var targetIds: [String]
    var color: Color
    @Binding var index: Int
    var onSelectTarget: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text("\(currentIndex + 1)/\(max(targetIds.count, 1)) locatable, \(count) total")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
            }

            Spacer(minLength: 0)

            Button {
                move(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(targetIds.count <= 1)
            .help("Previous \(title)")

            Button {
                onSelectTarget(targetIds[currentIndex])
            } label: {
                Label("Locate", systemImage: "scope")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
            }
            .buttonStyle(.plain)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .help("Locate current \(title)")

            Button {
                move(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(targetIds.count <= 1)
            .help("Next \(title)")
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
        .onChange(of: targetIds) { _ in
            index = currentIndex
        }
    }

    private var currentIndex: Int {
        guard !targetIds.isEmpty else { return 0 }
        return min(max(index, 0), targetIds.count - 1)
    }

    private func move(_ delta: Int) {
        guard !targetIds.isEmpty else { return }
        let nextIndex = (currentIndex + delta + targetIds.count) % targetIds.count
        index = nextIndex
        onSelectTarget(targetIds[nextIndex])
    }
}

private struct PPTXRepairActionCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: (String) -> Void
    var onConvertEditable: () -> Void
    var onExportPDF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Suggested Actions")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)

            VStack(spacing: 8) {
                if diagnostics.tableCount > 0 {
                    PPTXRepairActionRow(
                        icon: diagnostics.spanTableCount > 0 ? "tablecells.badge.ellipsis" : "tablecells",
                        title: "Review Tables",
                        detail: diagnostics.spanTableCount > 0 ? "\(diagnostics.tableCount) table(s), with merged cells" : "\(diagnostics.tableCount) table(s)",
                        color: warningColor,
                        buttonTitle: "Locate"
                    ) {
                        if let elementId = diagnostics.tableElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.tableElementId == nil)
                }

                if diagnostics.svgCount > 0 {
                    PPTXRepairActionRow(
                        icon: "scribble.variable",
                        title: "Review Vectors",
                        detail: "\(diagnostics.svgCount) SVG/vector object(s)",
                        color: warningColor,
                        buttonTitle: "Locate"
                    ) {
                        if let elementId = diagnostics.svgElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.svgElementId == nil)
                }

                if (diagnostics.pptxEffectRiskCount ?? 0) > 0 {
                    PPTXRepairActionRow(
                        icon: "camera.filters",
                        title: "Review Effects",
                        detail: "\(diagnostics.pptxEffectRiskCount ?? 0) complex visual effect(s)",
                        color: warningColor,
                        buttonTitle: "Locate"
                    ) {
                        if let elementId = diagnostics.pptxEffectRiskElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.pptxEffectRiskElementId == nil)
                }

                if (diagnostics.overlapCount ?? 0) > 0 {
                    PPTXRepairActionRow(
                        icon: "square.stack.3d.up",
                        title: "Review Layering",
                        detail: "\(diagnostics.overlapCount ?? 0) overlapping object(s)",
                        color: warningColor,
                        buttonTitle: "Locate"
                    ) {
                        if let elementId = diagnostics.overlapElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.overlapElementId == nil)
                }

                if diagnostics.shouldOfferEditableConversion {
                    PPTXRepairActionRow(
                        icon: "viewfinder",
                        title: "Convert to Editable Version",
                        detail: diagnostics.runtimeCompatibilityDetail,
                        color: MaterialTheme.primary,
                        buttonTitle: "Convert"
                    ) {
                        onConvertEditable()
                    }
                }

                if diagnostics.shouldOfferPDFFallback {
                    PPTXRepairActionRow(
                        icon: "doc.richtext",
                        title: "High-Fidelity Delivery",
                        detail: "Use PDF when visual consistency has priority",
                        color: MaterialTheme.accentSuccess,
                        buttonTitle: "Export PDF"
                    ) {
                        onExportPDF()
                    }
                }
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
    }

    private var warningColor: Color {
        MaterialTheme.accentWarning
    }
}

private struct PPTXRepairActionRow: View {
    var icon: String
    var title: String
    var detail: String
    var color: Color
    var buttonTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            Button(buttonTitle) {
                action()
            }
            .font(.system(size: 10, weight: .heavy))
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(color.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct PreflightNoteRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(MaterialTheme.primary)
                .frame(width: 18, height: 18)
                .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct PrecisionSafetyCard: View {
    var element: EditorElement
    var onLocate: (String) -> Void

    var body: some View {
        if let status = element.chiseloPrecisionSafetyStatus {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: status.icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(status.color)
                        .frame(width: 22, height: 22)
                        .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.title)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(MaterialTheme.ink)
                        Text(status.detail)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if !status.operations.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(status.operations.prefix(4), id: \.self) { operation in
                            Text(operation)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(status.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                                .lineLimit(1)
                        }
                    }
                }

                if status.targetId != nil || status.containerId != nil {
                    HStack(spacing: 7) {
                        if let targetId = status.targetId {
                            Button {
                                onLocate(targetId)
                            } label: {
                                Label("Object", systemImage: "scope")
                            }
                            .buttonStyle(CompactInspectorButtonStyle(color: status.color))
                        }

                        if let containerId = status.containerId, containerId != status.targetId {
                            Button {
                                onLocate(containerId)
                            } label: {
                                Label("Parent", systemImage: "rectangle.inset.filled")
                            }
                            .buttonStyle(CompactInspectorButtonStyle(color: MaterialTheme.primary))
                        }
                    }
                }
            }
            .padding(12)
            .background(status.color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(status.color.opacity(0.22), lineWidth: 1)
            )
        }
    }
}

private struct CompactInspectorButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(color.opacity(configuration.isPressed ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 6))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct EditableVersionSummary: Equatable {
    var pageCount: Int
    var totalObjects: Int
    var editableTextCount: Int
    var replaceableImageCount: Int
    var adjustableShapeCount: Int
    var approximatedCount: Int
    var wholeObjectCount: Int
    var iframeFallbackCount: Int
    var canvasFallbackCount: Int
    var pptxEditabilityScore: Int

    var directEditableCount: Int {
        editableTextCount + replaceableImageCount + adjustableShapeCount
    }

    var fallbackDetail: String {
        if wholeObjectCount == 0 {
            return "No whole-object fallbacks"
        }

        var parts: [String] = []
        if iframeFallbackCount > 0 { parts.append("\(iframeFallbackCount) embedded page(s)") }
        if canvasFallbackCount > 0 { parts.append("\(canvasFallbackCount) canvas region(s)") }
        let other = wholeObjectCount - iframeFallbackCount - canvasFallbackCount
        if other > 0 { parts.append("\(other) media/embedded object(s)") }
        return parts.joined(separator: ", ")
    }

    var pptxDetail: String {
        if pptxEditabilityScore >= 85 {
            return "Text, images, and shapes dominate, so PPTX editability is good."
        }
        if pptxEditabilityScore >= 65 {
            return "Approximated or whole objects are present, so review object layering closely after PPTX export."
        }
        return "There are many whole-object fallbacks. PPTX suits layout review rather than fully separable editing."
    }

    var qualityTitle: String {
        if pptxEditabilityScore >= 85 { return "Good editability" }
        if pptxEditabilityScore >= 65 { return "Moderate editability" }
        return "Needs review"
    }

    var qualityIcon: String {
        if pptxEditabilityScore >= 85 { return "checkmark.seal.fill" }
        if pptxEditabilityScore >= 65 { return "exclamationmark.triangle.fill" }
        return "rectangle.dashed"
    }

    var qualityColor: Color {
        if pptxEditabilityScore >= 85 { return MaterialTheme.accentSuccess }
        if pptxEditabilityScore >= 65 { return MaterialTheme.accentWarning }
        return MaterialTheme.accentDanger
    }
}

private struct EditableVersionQualityCard: View {
    var summary: EditableVersionSummary
    var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: summary.qualityIcon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(summary.qualityColor)
                    .frame(width: 22, height: 22)
                    .background(summary.qualityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Editable Version Quality")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("\(summary.qualityTitle) · PPTX \(summary.pptxEditabilityScore)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(summary.qualityColor)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                EditableQualityMetric(value: "\(summary.editableTextCount)", label: "Text", icon: "textformat")
                EditableQualityMetric(value: "\(summary.replaceableImageCount)", label: "Images", icon: "photo")
                EditableQualityMetric(value: "\(summary.adjustableShapeCount)", label: "Shapes", icon: "square")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    PreflightNoteRow(icon: "square.grid.2x2", title: "Directly editable objects", detail: "\(summary.directEditableCount) / \(summary.totalObjects) object(s) support direct text, image, or shape edits")
                    PreflightNoteRow(icon: "wand.and.rays", title: "Approximated", detail: "\(summary.approximatedCount) pseudo-element(s) or complex visual(s) converted to approximated objects")
                    PreflightNoteRow(icon: "rectangle.dashed", title: "Whole-object fidelity", detail: summary.fallbackDetail)
                }
            } else if summary.wholeObjectCount > 0 || summary.approximatedCount > 0 {
                Text("\(summary.approximatedCount) approximated object(s), \(summary.wholeObjectCount) whole-object fidelity object(s)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            } else {
                Text("This conversion is made up mostly of editable text, images, and shapes.")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(summary.qualityColor.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.10), radius: 8, x: 0, y: 3)
    }
}

private struct EditableQualityMetric: View {
    var value: String
    var label: String
    var icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 10, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private extension EditorDeck {
    var editableVersionSummary: EditableVersionSummary? {
        guard irVersion == "layout-ir-v1" || sourceKind == "runtime-html-snapshot" else { return nil }

        let elements = slides.flatMap(\.elements)
        guard !elements.isEmpty else { return nil }

        var editableText = 0
        var replaceableImages = 0
        var adjustableShapes = 0
        var approximated = 0
        var wholeObjects = 0
        var iframeFallbacks = 0
        var canvasFallbacks = 0

        for element in elements {
            switch element.editability {
            case "text-editable":
                editableText += 1
            case "replaceable":
                replaceableImages += 1
            case "style-editable":
                adjustableShapes += 1
            case "whole-object":
                wholeObjects += 1
                if element.tagName == "iframe" { iframeFallbacks += 1 }
                if element.tagName == "canvas" { canvasFallbacks += 1 }
            default:
                break
            }

            if element.fidelity == "approximated" {
                approximated += 1
            }
        }

        let total = elements.count
        let score = min(100, max(0,
            100
            - min(45, wholeObjects * 12)
            - min(24, approximated * 4)
            - max(0, total - editableText - replaceableImages - adjustableShapes - wholeObjects) * 2
        ))

        return EditableVersionSummary(
            pageCount: slides.count,
            totalObjects: total,
            editableTextCount: editableText,
            replaceableImageCount: replaceableImages,
            adjustableShapeCount: adjustableShapes,
            approximatedCount: approximated,
            wholeObjectCount: wholeObjects,
            iframeFallbackCount: iframeFallbacks,
            canvasFallbackCount: canvasFallbacks,
            pptxEditabilityScore: score
        )
    }
}

private struct HistoryBrowserPanel: View {
    @EnvironmentObject private var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(MaterialTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Version History")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer()

                Button {
                    model.refreshHistorySnapshots()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(MaterialButtonStyle())
            }
            .padding(20)
            .background(MaterialTheme.surfaceStrong)

            if model.historySnapshots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(model.historySnapshots.enumerated()), id: \.element.id) { index, snapshot in
                            HistorySnapshotRow(
                                snapshot: snapshot,
                                isLatest: index == 0,
                                isSelected: snapshot.id == model.selectedHistorySnapshotID
                            ) {
                                model.selectedHistorySnapshotID = snapshot.id
                            }
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    model.revealSafetyFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .buttonStyle(MaterialButtonStyle())

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(MaterialButtonStyle())

                Button {
                    model.restoreSelectedHistorySnapshot()
                } label: {
                    Label("Restore Selected", systemImage: "arrow.counterclockwise.circle")
                }
                .buttonStyle(MaterialButtonStyle(filled: true))
                .disabled(model.selectedHistorySnapshotID == nil)
            }
            .padding(16)
            .background(MaterialTheme.surfaceStrong)
        }
        .frame(width: 620, height: 560)
        .onAppear {
            model.refreshHistorySnapshots()
        }
    }

    private var headerSubtitle: String {
        if model.historySnapshots.isEmpty {
            return "This file has no restorable snapshots yet"
        }
        return "\(model.historySnapshots.count) restorable version(s), newest first"
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MaterialTheme.primary)
            Text("No snapshots saved yet")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)
            Text("When you overwrite an HTML or Chiselo project file, Chiselo moves the previous version into `.chiselo-history` so you can review and restore it here.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct HistorySnapshotRow: View {
    var snapshot: SafeFileHistory.VersionSnapshot
    var isLatest: Bool
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                    .frame(width: 26, height: 26)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(formatDate(snapshot.createdAt))
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
                        if isLatest {
                            Text("Newest")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(latestBadgeBackground, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }

                    Text(snapshot.filename)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.86) : MaterialTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text(formatBytes(snapshot.byteCount))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : MaterialTheme.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isSelected ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private var rowBackground: Color {
        isSelected ? MaterialTheme.primary : MaterialTheme.surfaceTint
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.18) : MaterialTheme.primary.opacity(0.10)
    }

    private var latestBadgeBackground: Color {
        isSelected ? Color.white.opacity(0.18) : MaterialTheme.primary.opacity(0.10)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Unknown time" }
        return Self.dateFormatter.string(from: date)
    }

    private func formatBytes(_ byteCount: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: byteCount)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct DocumentNavigator: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialPanelHeader(title: navigatorTitle, subtitle: navigatorSubtitle)
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.top, MaterialTheme.panelPadding)

            NavigatorMetricsBar(
                pageCount: model.documentStats.pageCount,
                objectCount: model.documentStats.objectCount,
                imageCount: model.documentStats.imageCount,
                htmlNodeCount: model.documentStats.htmlNodeCount
            )
            .padding(.horizontal, MaterialTheme.panelPadding)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.deck == nil {
                        HTMLDocumentCard()
                        HTMLDeliveryCheckCard(diagnostics: model.htmlDiagnostics)

                        if model.workspaceMode == .advanced, !model.htmlTree.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Object Structure")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)

                                HTMLTreeList(nodes: model.htmlTree)
                            }
                        }
                    }

                    if let summary = model.deck?.editableVersionSummary {
                        EditableVersionQualityCard(summary: summary, isExpanded: false)
                    }

                    ForEach(Array((model.deck?.slides ?? []).enumerated()), id: \.element.id) { index, slide in
                        Button {
                            model.selectSlide(index: index)
                        } label: {
                            SlideThumbnailView(
                                slide: slide,
                                canvas: model.deck?.canvas,
                                index: index,
                                isSelected: index == model.selectedSlideIndex
                            )
                            .equatable()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .background(MaterialSidebarBackground())
    }

    private var navigatorTitle: String {
        model.documentMode == "html" ? "Document" : "Page"
    }

    private var navigatorSubtitle: String {
        model.documentMode == "html" ? "Page objects" : "Layout and objects"
    }

}

private struct NavigatorMetricsBar: View {
    var pageCount: Int?
    var objectCount: Int?
    var imageCount: Int?
    var htmlNodeCount: Int?

    var body: some View {
        HStack(spacing: 6) {
            if let pageCount {
                MetricPill(value: "\(pageCount)", label: "Pages", icon: "rectangle.on.rectangle")
            }

            if let objectCount {
                MetricPill(value: "\(objectCount)", label: "Objects", icon: "square.3.layers.3d")
            }

            if let imageCount, imageCount > 0 {
                MetricPill(value: "\(imageCount)", label: "Images", icon: "photo")
            }

            if let htmlNodeCount, htmlNodeCount > 0 {
                MetricPill(value: "\(htmlNodeCount)", label: "Objects", icon: "square.3.layers.3d")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricPill: View {
    var value: String
    var label: String
    var icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 10, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct CSSPaintView: View {
    var value: String?
    var fallback: Color

    var body: some View {
        if let gradient = cssLinearGradient(value) {
            LinearGradient(
                gradient: Gradient(stops: gradient.stops),
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else {
            cssColor(value, fallback: fallback)
        }
    }
}

private struct CSSLinearGradient {
    var startPoint: UnitPoint
    var endPoint: UnitPoint
    var stops: [Gradient.Stop]
}


private struct SlideThumbnailView: View, Equatable {
    private static let maxPreviewElements = 90

    var slide: EditorSlide
    var canvas: EditorCanvas?
    var index: Int
    var isSelected: Bool

    private var canvasWidth: Double {
        max(1, canvas?.width ?? 1280)
    }

    private var canvasHeight: Double {
        max(1, canvas?.height ?? 720)
    }

    private var aspectRatio: Double {
        canvasWidth / canvasHeight
    }

    private var previewElements: [EditorElement] {
        let sorted = slide.elements.sorted { left, right in
            if left.z == right.z { return left.id < right.id }
            return left.z < right.z
        }
        guard sorted.count > Self.maxPreviewElements else { return sorted }

        var elements = Array(sorted.prefix(24))
        elements.append(contentsOf: sorted.suffix(Self.maxPreviewElements - elements.count))
        return elements
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                CSSPaintView(value: canvas?.background, fallback: Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))

                GeometryReader { proxy in
                    let scaleX = proxy.size.width / canvasWidth
                    let scaleY = proxy.size.height / canvasHeight

                    ZStack(alignment: .topLeading) {
                        ForEach(previewElements) { element in
                            ThumbnailElementView(
                                element: element,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                renderImages: isSelected
                            )
                            .equatable()
                        }
                    }
                    .clipped()
                }
                .padding(7)

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MaterialTheme.primary, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
                    .padding(7)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.primary.opacity(isSelected ? 0.82 : 0.18), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(isSelected ? 0.22 : 0.12), radius: 9, x: 0, y: 3)

            HStack(spacing: 6) {
                Text(slide.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
                SlideObjectSummary(elements: slide.elements)
            }
            .padding(.horizontal, 2)
        }
    }

}

private struct SlideObjectSummary: View, Equatable {
    let totalCount: Int
    let imageCount: Int
    let textCount: Int
    let shapeCount: Int

    init(elements: [EditorElement]) {
        totalCount = elements.count
        var images = 0
        var texts = 0

        for element in elements {
            if element.type == "image" {
                images += 1
            } else if element.type == "text" {
                texts += 1
            }
        }

        imageCount = images
        textCount = texts
        shapeCount = elements.count - images - texts
    }

    var body: some View {
        HStack(spacing: 4) {
            if imageCount > 0 {
                Label("\(imageCount)", systemImage: "photo")
            }
            if textCount > 0 {
                Label("\(textCount)", systemImage: "textformat")
            }
            if shapeCount > 0 {
                Label("\(shapeCount)", systemImage: "square")
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(MaterialTheme.muted)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityLabel("\(totalCount) object(s)")
    }
}

private struct ThumbnailElementView: View, Equatable {
    var element: EditorElement
    var scaleX: Double
    var scaleY: Double
    var renderImages: Bool

    var body: some View {
        Group {
            if element.type == "text" {
                Text(element.text ?? "")
                    .font(.system(size: thumbnailFontSize, weight: thumbnailFontWeight))
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .foregroundStyle(cssColor(element.style?.color, fallback: MaterialTheme.ink))
                    .frame(width: scaledWidth, height: scaledHeight, alignment: alignment)
                    .clipped()
            } else if element.type == "image" {
                imagePreview
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipShape(RoundedRectangle(cornerRadius: scaledRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: scaledRadius)
                            .stroke(cssColor(element.style?.stroke, fallback: Color.clear), lineWidth: scaledStrokeWidth)
                    )
            } else {
                CSSPaintView(value: element.style?.fill, fallback: Color.clear)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipShape(RoundedRectangle(cornerRadius: scaledRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: scaledRadius)
                            .stroke(cssColor(element.style?.stroke, fallback: Color.clear), lineWidth: scaledStrokeWidth)
                    )
            }
        }
        .position(x: scaledX + scaledWidth / 2, y: scaledY + scaledHeight / 2)
        .rotationEffect(.degrees(element.rotation))
    }

    @ViewBuilder
    private var imagePreview: some View {
        if renderImages {
            thumbnailImage
        } else {
            imagePlaceholder
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let nsImage = nsImageFromDataURL(element.imageSource) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let source = element.imageSource,
                  let url = URL(string: source),
                  ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: scaledRadius)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.93, blue: 0.99),
                        Color(red: 0.98, green: 0.98, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Image(systemName: "photo")
                .font(.system(size: max(8, min(scaledWidth, scaledHeight) * 0.24), weight: .bold))
                .foregroundStyle(MaterialTheme.primary.opacity(0.68))
        }
    }

    private var scaledX: Double { element.x * scaleX }
    private var scaledY: Double { element.y * scaleY }
    private var scaledWidth: Double { max(1, element.w * scaleX) }
    private var scaledHeight: Double { max(1, element.h * scaleY) }
    private var scaledRadius: Double { max(0, (element.style?.radius ?? 0) * min(scaleX, scaleY)) }
    private var scaledStrokeWidth: Double { max(0.4, (element.style?.strokeWidth ?? 0) * min(scaleX, scaleY)) }
    private var thumbnailFontSize: CGFloat { max(5, CGFloat((element.style?.fontSize ?? 16) * min(scaleX, scaleY))) }

    private var thumbnailFontWeight: Font.Weight {
        let weight = element.style?.fontWeight ?? 400
        if weight >= 750 { return .heavy }
        if weight >= 650 { return .bold }
        if weight >= 550 { return .semibold }
        return .regular
    }

    private var textAlignment: TextAlignment {
        switch element.style?.textAlign {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var alignment: Alignment {
        switch element.style?.textAlign {
        case "center": return .top
        case "right": return .topTrailing
        default: return .topLeading
        }
    }
}

private struct HTMLTreeList: View {
    @EnvironmentObject private var model: EditorModel
    var nodes: [HTMLTreeNode]

    var body: some View {
        let selectedID = model.selectedElement?.id

        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(nodes) { node in
                HTMLTreeRow(node: node, depth: 0, selectedID: selectedID)
                    .equatable()
            }
        }
    }
}

private struct HTMLTreeRow: View, Equatable {
    @EnvironmentObject private var model: EditorModel
    var node: HTMLTreeNode
    var depth: Int
    var selectedID: String?

    static func == (lhs: HTMLTreeRow, rhs: HTMLTreeRow) -> Bool {
        lhs.node == rhs.node && lhs.depth == rhs.depth && lhs.selectedID == rhs.selectedID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                model.selectHTMLNode(id: node.id)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: hasChildren ? "chevron.down" : "circle.fill")
                        .font(.system(size: hasChildren ? 8 : 4, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.84) : MaterialTheme.muted.opacity(0.62))
                        .frame(width: 10, height: 12)

                    Image(systemName: node.chiseloIconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.primaryDark)
                        .frame(width: 14, height: 14)

                    Text(node.chiseloTypeLabel)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.primaryDark)
                        .frame(width: 56, alignment: .leading)

                    Text(node.label)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(depth) * 10)
                .padding(.vertical, 6)
                .padding(.horizontal, 7)
                .background(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .fill(rowFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .stroke(isSelected ? Color.clear : MaterialTheme.separator, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(node.path)
            .accessibilityLabel("\(node.chiseloTypeLabel): \(node.label)")
            .accessibilityHint("Select this object")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            if let children = node.children {
                ForEach(children) { child in
                    HTMLTreeRow(node: child, depth: depth + 1, selectedID: selectedID)
                        .equatable()
                }
            }
        }
    }

    private var isSelected: Bool {
        selectedID == node.id
    }

    private var hasChildren: Bool {
        !(node.children?.isEmpty ?? true)
    }

    private var rowFill: Color {
        if isSelected { return MaterialTheme.primary }
        return depth == 0 ? MaterialTheme.surfaceStrong : MaterialTheme.surfaceTint.opacity(0.66)
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case content = "Content"
    case style = "Appearance"
    case layout = "Position"
    case arrange = "Layers"
    case html = "Source"

    var id: String { rawValue }
}

private struct GeometryMetrics {
    var element: EditorElement
    var frame: EditorElementFrame

    var frameLabel: String {
        frame.label?.isEmpty == false ? frame.label! : "Canvas"
    }

    var left: Double { element.x - frame.x }
    var top: Double { element.y - frame.y }
    var right: Double { frame.x + frame.w - element.x - element.w }
    var bottom: Double { frame.y + frame.h - element.y - element.h }
    var centerXOffset: Double { element.x + element.w / 2 - (frame.x + frame.w / 2) }
    var centerYOffset: Double { element.y + element.h / 2 - (frame.y + frame.h / 2) }

    var summary: String {
        [
            "Object: \(element.chiseloTypeLabel)",
            "Position: X \(rounded(element.x)), Y \(rounded(element.y)), W \(rounded(element.w)), H \(rounded(element.h))",
            "\(frameLabel): W \(rounded(frame.w)), H \(rounded(frame.h))",
            "Margins: left \(rounded(left)), top \(rounded(top)), right \(rounded(right)), bottom \(rounded(bottom))",
            "Center offset: X \(signed(centerXOffset)), Y \(signed(centerYOffset))"
        ].joined(separator: "\n")
    }

    private func rounded(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func signed(_ value: Double) -> String {
        let roundedValue = Int(value.rounded())
        return roundedValue > 0 ? "+\(roundedValue)" : "\(roundedValue)"
    }
}

private struct InspectorPanel: View {
    @EnvironmentObject private var model: EditorModel
    @State private var selectedTab: InspectorTab = .content
    @State private var sourceDraft = ""
    @State private var sourceDraftElementID: String?
    @State private var sourceDraftOriginalSnippet = ""
    @State private var htmlPseudoPreviewState = "none"
    @State private var stylesheetRuleDraft = ""
    @State private var stylesheetRuleDraftElementID: String?
    @State private var stylesheetRuleOriginalSnippet = ""
    @State private var stylesheetRuleValidationMessage: String?
    @State private var stylesheetRuleValidationTask: Task<Void, Never>?
    @State private var attributeDraftElementID: String?
    @State private var classNameDraft = ""
    @State private var inlineStyleDraft = ""
    @State private var linkHrefDraft = ""
    @State private var linkTargetDraft = ""
    @State private var pendingSourceDraftValidationID: UUID?
    @State private var sourceDraftValidationTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaterialPanelHeader(title: "Properties", subtitle: "Common edits")
                .padding(MaterialTheme.panelPadding)

            if let element = model.selectedElement {
                InspectorSelectionHeader(element: element, path: element.htmlPath ?? model.selectionPath)
                    .padding(.horizontal, MaterialTheme.panelPadding)
                    .padding(.bottom, 10)

                Picker("Inspector Section", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.bottom, 8)
                .onAppear(perform: normalizeSelectedTab)
                .onChange(of: model.documentMode) { _ in
                    normalizeSelectedTab()
                }
                .onAppear {
                    syncSourceDraft(for: element)
                    syncHTMLAttributeDrafts(for: element)
                    syncStylesheetRuleDraft(for: element)
                }
                .onChange(of: element.id) { _ in
                    syncSourceDraft(for: element)
                    syncHTMLAttributeDrafts(for: element)
                    syncStylesheetRuleDraft(for: element)
                }
                .onChange(of: element.sourceSnippet) { _ in
                    syncSourceDraft(for: element)
                }
                .onChange(of: element.style?.writebackRuleSnippet) { _ in
                    syncStylesheetRuleDraft(for: element)
                }
                .onChange(of: sourceDraft) { _ in
                    scheduleSourceDraftValidationPreview(for: element)
                }
                .onChange(of: stylesheetRuleDraft) { _ in
                    scheduleStylesheetRuleValidation(for: element)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        inspectorContent(for: element)
                    }
                    .padding(MaterialTheme.panelPadding)
                    .groupBoxStyle(MaterialGroupBoxStyle())
                }
            } else {
                emptySelection
            }
        }
        .background(MaterialSidebarBackground())
    }

    private var availableTabs: [InspectorTab] {
        if model.workspaceMode == .ordinary {
            return [.content, .style, .layout]
        }
        return model.documentMode == "html" ? InspectorTab.allCases : [.content, .style, .layout, .arrange]
    }

    private var activeTab: InspectorTab {
        availableTabs.contains(selectedTab) ? selectedTab : .content
    }

    private func normalizeSelectedTab() {
        if !availableTabs.contains(selectedTab) {
            selectedTab = .content
        }
    }

    private func syncSourceDraft(for element: EditorElement) {
        let snippet = element.sourceSnippet ?? ""
        guard sourceDraftElementID != element.id else {
            if sourceDraftOriginalSnippet != snippet {
                invalidateSourceDraftValidationPreview()
                sourceDraft = snippet
                sourceDraftOriginalSnippet = snippet
                scheduleSourceDraftValidationPreview(for: element, delay: 0)
            } else if sourceDraft.isEmpty, !snippet.isEmpty {
                invalidateSourceDraftValidationPreview()
                sourceDraft = snippet
                scheduleSourceDraftValidationPreview(for: element, delay: 0)
            }
            return
        }
        invalidateSourceDraftValidationPreview()
        sourceDraftElementID = element.id
        sourceDraftOriginalSnippet = snippet
        sourceDraft = snippet
        scheduleSourceDraftValidationPreview(for: element, delay: 0)
    }

    private func syncHTMLAttributeDrafts(for element: EditorElement) {
        attributeDraftElementID = element.id
        classNameDraft = element.className ?? ""
        inlineStyleDraft = element.inlineStyle ?? ""
        linkHrefDraft = element.linkHref ?? ""
        linkTargetDraft = element.linkTarget ?? ""
    }

    @ViewBuilder
    private func inspectorContent(for element: EditorElement) -> some View {
        if model.documentMode == "html" {
            PrecisionSafetyCard(element: element) { elementId in
                model.selectHTMLNode(id: elementId)
            }
        }

        switch activeTab {
        case .content:
            contentGroups(for: element)
        case .layout:
            geometryGroup
            if !isGeometryLockedSelection {
                quickAdjustGroup
                alignmentGroup(for: element)
            }
        case .style:
            styleGroups(for: element)
            boxStyleGroup
            boxModelGroup
            layoutGroup
            miscStyleGroup
            htmlAssetGroups
        case .arrange:
            if !isGeometryLockedSelection {
                layerStackGroup
                layerGroup
                alignmentGroup(for: element)
            }
        case .html:
            objectGroup(element)
            htmlAttributesGroup(element)
            htmlSourceSyncGroup(element)
            htmlControlsGroup
        }
    }

    private var emptySelection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 26))
                        .foregroundStyle(MaterialTheme.primary)
                    Text("Select an object")
                        .font(.headline)
                        .foregroundStyle(MaterialTheme.ink)
                    Text("Select text, an image, a shape, or a table to show common edits here.")
                        .font(.callout)
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(18)
                .materialCard()

                if model.documentMode != "html", !model.currentSlideElements.isEmpty {
                    layerStackGroup
                }
            }
            .padding(MaterialTheme.panelPadding)
            .groupBoxStyle(MaterialGroupBoxStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func objectGroup(_ element: EditorElement) -> some View {
        GroupBox("Object") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Object", value: element.chiseloTypeLabel)
                if let writeback = element.style?.writebackStatus {
                    SourceWritebackStatusBadge(status: writeback)
                }
                if element.groupLabel != nil || element.groupId != nil {
                    GroupMembershipBadge(element: element, compact: false)
                    if element.type != "deck-group" {
                        CommandButton(title: "Select Module", icon: "square.3.layers.3d", command: "selectModuleGroup")
                            .help("Select the parent module to move, align, and snap it as one group")
                    }
                }
                LabeledContent("ID", value: element.id)
                if let tagName = element.tagName {
                    LabeledContent("Original tag", value: tagName)
                }
                if let layoutMode = element.layoutMode {
                    LabeledContent("Layout", value: layoutMode)
                }
                if let path = element.htmlPath ?? model.selectionPath {
                    Text("Original position")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(MaterialTheme.primary)
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func htmlAttributesGroup(_ element: EditorElement) -> some View {
        GroupBox("HTML Attributes / CSS") {
            VStack(alignment: .leading, spacing: 10) {
                StyleTextField(label: "class", value: $classNameDraft)

                VStack(alignment: .leading, spacing: 4) {
                    Text("inline style")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(MaterialTheme.primary)
                    TextEditor(text: $inlineStyleDraft)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MaterialTheme.ink)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 58, maxHeight: 118)
                        .background(MaterialInputBackground())
                }

                if supportsLinkAttributes(element) {
                    Divider()
                    StyleTextField(label: "href", value: $linkHrefDraft)
                    StyleTextField(label: "target", value: $linkTargetDraft)
                }

                HStack(spacing: 8) {
                    Button {
                        model.applySelectedHTMLAttributes(
                            className: classNameDraft,
                            inlineStyle: inlineStyleDraft,
                            linkHref: supportsLinkAttributes(element) ? linkHrefDraft : "",
                            linkTarget: supportsLinkAttributes(element) ? linkTargetDraft : ""
                        )
                    } label: {
                        Label("Apply Attributes", systemImage: "checkmark.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MaterialButtonStyle(compact: true))
                    .disabled(!canApplyHTMLAttributeDrafts(for: element))

                    Button {
                        syncHTMLAttributeDrafts(for: element)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MaterialButtonStyle(compact: true))
                }
            }
        }
    }

    @ViewBuilder
    private func contentGroups(for element: EditorElement) -> some View {
        if supportsTextControls(element) {
            textContentGroup
        }

        if supportsImageControls(element) {
            imageInfoGroup
        }

        if model.documentMode == "html", isTableSelection {
            tableGroup
        }

        if model.documentMode == "html", isCellSelection {
            cellStyleGroup
        }

        quickAdjustGroup
    }

    private var textContentGroup: some View {
        GroupBox("Text Content") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: textContentBinding(defaultValue: ""))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MaterialTheme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 76, maxHeight: 132)
                    .background(MaterialInputBackground())

                Text("This changes only the selected object's text. It does not change similar objects.")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var geometryGroup: some View {
        if isGeometryLockedSelection {
            GroupBox("Safe Table Editing") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cells remain in the table flow. This prevents position or size changes from moving or clipping other cells.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            CommandButton(title: "Edit Text", icon: "text.cursor", command: "editText")
                            CommandButton(title: "Whole Table", icon: "tablecells", command: "selectTable")
                        }
                    }

                    if isTableSelection {
                        tableOperationGrid
                    }

                    if isCellSelection {
                        cellActionGrid
                    }
                }
            }
        } else {
            GroupBox("Geometry") {
            VStack(alignment: .leading, spacing: 12) {
                if let notice = model.selectedElement?.chiseloGeometrySafetyNotice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: notice.icon)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(notice.color)
                            .frame(width: 18, height: 18)
                            .background(notice.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                        Text(notice.detail)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(9)
                    .background(notice.color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                }

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "X", value: binding(\.x))
                        NumberField(label: "Y", value: binding(\.y))
                    }
                    GridRow {
                        NumberField(label: "W", value: binding(\.w))
                        NumberField(label: "H", value: binding(\.h))
                    }
                    GridRow {
                        NumberField(label: "Rotation", value: binding(\.rotation))
                        NumberField(label: "Z", value: binding(\.z))
                    }
                }

                if let metrics = selectedGeometryMetrics {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(metrics.frameLabel, systemImage: "viewfinder")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(MaterialTheme.primary)
                            Spacer()
                            Text("\(formatMetric(metrics.frame.w)) x \(formatMetric(metrics.frame.h))")
                                .font(.caption)
                                .foregroundStyle(MaterialTheme.muted)
                        }

                        GeometryMetricGrid(metrics: metrics)

                        Button {
                            copyGeometrySummary(metrics)
                        } label: {
                            Label("Copy Geometry", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                        .help("Copy position, size, margins, and center offset for before/after review")
                    }
                }
            }
        }
        }
    }

    @ViewBuilder
    private var quickAdjustGroup: some View {
        if !isGeometryLockedSelection {
            GroupBox("Quick Adjustments") {
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "Top", icon: "align.vertical.top", command: "alignTop")
                        CommandButton(title: "Middle", icon: "align.vertical.center", command: "alignMiddle")
                        CommandButton(title: "Bottom", icon: "align.vertical.bottom", command: "alignBottom")
                    }
                    GridRow {
                        CommandButton(title: "Left", icon: "align.horizontal.left", command: "alignLeft")
                        CommandButton(title: "Center", icon: "align.horizontal.center", command: "alignCenter")
                        CommandButton(title: "Right", icon: "align.horizontal.right", command: "alignRight")
                    }
                    GridRow {
                        CommandButton(title: "Fit W", icon: "arrow.left.and.right", command: "fitWidth")
                        CommandButton(title: "Fit H", icon: "arrow.up.and.down", command: "fitHeight")
                        CommandButton(title: "Fill Page", icon: "rectangle.inset.filled", command: "fitPage")
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Spacer()
                        CommandButton(title: "Up", icon: "arrow.up", command: "nudgeUp")
                        Spacer()
                    }
                    GridRow {
                        CommandButton(title: "Left", icon: "arrow.left", command: "nudgeLeft")
                        CommandButton(title: "Snap", icon: "grid", command: "snapToGrid")
                        CommandButton(title: "Right", icon: "arrow.right", command: "nudgeRight")
                    }
                    GridRow {
                        Spacer()
                        CommandButton(title: "Down", icon: "arrow.down", command: "nudgeDown")
                        Spacer()
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "-10 X", icon: "arrow.left.to.line", command: "nudgeLeftBig")
                        CommandButton(title: "+10 X", icon: "arrow.right.to.line", command: "nudgeRightBig")
                    }
                    GridRow {
                        CommandButton(title: "-10 Y", icon: "arrow.up.to.line", command: "nudgeUpBig")
                        CommandButton(title: "+10 Y", icon: "arrow.down.to.line", command: "nudgeDownBig")
                    }
                }
            }
        }
        }
    }

    private var textStyleGroup: some View {
        GroupBox("Text") {
            VStack(alignment: .leading, spacing: 12) {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "Size", value: styleDoubleBinding(\.fontSize, defaultValue: 16))
                        NumberField(label: "Weight", value: styleDoubleBinding(\.fontWeight, defaultValue: 400))
                    }
                    GridRow {
                        NumberField(label: "Line height", value: styleDoubleBinding(\.lineHeight, defaultValue: 1.2), fractionLength: 2)
                        StyleTextField(label: "Font name", value: styleStringBinding(\.fontFamily, defaultValue: "-apple-system"))
                    }
                }

                styleColorSwatches(
                    title: "Text color",
                    value: styleStringBinding(\.color, defaultValue: "#111827"),
                    presets: textColorPresets
                )
                StyleTextField(label: "Exact color", value: styleStringBinding(\.color, defaultValue: "#111827"))
                styleChoiceRow(
                    title: "Text alignment",
                    value: styleStringBinding(\.textAlign, defaultValue: "left"),
                    options: textAlignmentPresets
                )
            }
        }
    }

    @ViewBuilder
    private func styleGroups(for element: EditorElement) -> some View {
        if let style = element.style, style.writebackStatus != nil {
            styleWritebackGroup(style)
        }

        if supportsTextControls(element) {
            textStyleGroup
        }

        if supportsImageControls(element) {
            imageInfoGroup
        }
    }

    @ViewBuilder
    private func styleWritebackGroup(_ style: EditorElementStyle) -> some View {
        if let status = style.writebackStatus {
            GroupBox("Source Writeback") {
            VStack(alignment: .leading, spacing: 10) {
                SourceWritebackStatusBadge(status: status)

                if let ruleLine = status.ruleLine {
                    Text("Approximate rule line: \(ruleLine)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(status.color)
                }

                if let ruleSnippet = status.ruleSnippet {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(ruleSnippet)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MaterialTheme.ink)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 52, maxHeight: 120, alignment: .topLeading)
                    .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                            .stroke(MaterialTheme.hairline, lineWidth: 1)
                    )
                }

                HStack(spacing: 8) {
                    if let ruleSnippet = status.ruleSnippet {
                        Button {
                            copySourceSnippet(ruleSnippet)
                            model.status = "CSS rule snippet copied"
                        } label: {
                            Label("Copy Rule", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                    }

                    if status.target != nil {
                        Button {
                            model.selectNodesForSelectedStylesheetRule()
                        } label: {
                            Label("Select Matching Objects", systemImage: "scope")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                    }

                    if let sourceURL = status.sourceURL, !sourceURL.isEmpty {
                        Button {
                            model.revealLocalResource(urlString: sourceURL)
                        } label: {
                            Label("Locate File", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                    }
                }

                if let ruleSnippet = status.ruleSnippet {
                    Divider()

                    Text("Rule Editor")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)

                    ScrollView(.horizontal, showsIndicators: true) {
                        TextEditor(text: $stylesheetRuleDraft)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MaterialTheme.ink)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 72, maxHeight: 180, alignment: .topLeading)
                    .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                            .stroke(MaterialTheme.hairline, lineWidth: 1)
                    )

                    if let validationMessage = stylesheetRuleValidationMessage,
                       stylesheetRuleDraft.trimmingCharacters(in: .whitespacesAndNewlines) != ruleSnippet.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Text(validationMessage)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MaterialTheme.accentDanger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Button {
                            restoreStylesheetRuleDraft(for: style)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                        .disabled(!canRestoreStylesheetRuleDraft(for: style))

                        Button {
                            model.applySelectedStylesheetRule(stylesheetRuleDraft)
                        } label: {
                            Label("Apply Rule", systemImage: "checkmark.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                        .disabled(!canApplyStylesheetRuleDraft(for: style))
                    }
                }

                if let matchSummary = style.writebackMatchSummary, !matchSummary.items.isEmpty {
                    Divider()
                    stylesheetRuleMatchSummaryGroup(matchSummary)
                }
            }
        }
        }
    }

    private func stylesheetRuleMatchSummaryGroup(_ summary: StylesheetRuleMatchSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                Text("Matching Objects")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text("\(summary.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MaterialTheme.primaryDark)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 0)
            }

            LazyVStack(spacing: 5) {
                ForEach(summary.items) { item in
                    stylesheetRuleMatchRow(item, selector: summary.selector)
                }

                if summary.count > summary.items.count {
                    Text("\(summary.count - summary.items.count) more objects match. Use Select Matching Objects to review the complete group.")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                }
            }
        }
        .padding(8)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private func stylesheetRuleMatchRow(_ item: EditorSourceNodeItem, selector: String) -> some View {
        Button {
            locateSourceNodeItem(item, statusPrefix: "Located matching rule object")
        } label: {
            HStack(alignment: .top, spacing: 7) {
                Text(item.tagName.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MaterialTheme.primaryDark)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label.isEmpty ? item.tagName : item.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.path)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Image(systemName: "scope")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(MaterialTheme.separator, lineWidth: 1)
        )
        .help("\(selector)\n\(item.path)")
    }

    private var imageInfoGroup: some View {
        GroupBox("Image") {
            VStack(spacing: 10) {
                StyleTextField(label: "Source", value: imageSourceBinding(defaultValue: ""))
                StyleTextField(label: "ALT", value: imageAltBinding(defaultValue: ""))
                styleChoiceRow(
                    title: "Display Mode",
                    value: styleStringBinding(\.objectFit, defaultValue: "cover"),
                    options: imageFitPresets
                )

                if model.documentMode == "html" {
                    Button {
                        model.replaceSelectedImage()
                    } label: {
                        Label("Replace Image", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MaterialButtonStyle(filled: true))
                }
            }
        }
    }

    private var boxStyleGroup: some View {
        GroupBox("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                styleColorSwatches(
                    title: "Fill",
                    value: styleStringBinding(\.fill, defaultValue: "transparent"),
                    presets: fillColorPresets
                )
                StyleTextField(label: "Exact fill", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                styleColorSwatches(
                    title: "Stroke",
                    value: styleStringBinding(\.stroke, defaultValue: "transparent"),
                    presets: strokeColorPresets
                )
                StyleTextField(label: "Exact stroke", value: styleStringBinding(\.stroke, defaultValue: "transparent"))

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "Border", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                        NumberField(label: "Radius", value: styleDoubleBinding(\.radius, defaultValue: 0))
                    }
                }

                styleChoiceRow(
                    title: "Shadow",
                    value: styleStringBinding(\.shadow, defaultValue: "none"),
                    options: shadowPresets
                )
            }
        }
    }

    private var boxModelGroup: some View {
        GroupBox("Box Model") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Padding")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.muted)
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "Top", value: styleDoubleBinding(\.paddingTop, defaultValue: 0))
                        NumberField(label: "Right", value: styleDoubleBinding(\.paddingRight, defaultValue: 0))
                    }
                    GridRow {
                        NumberField(label: "Bottom", value: styleDoubleBinding(\.paddingBottom, defaultValue: 0))
                        NumberField(label: "Left", value: styleDoubleBinding(\.paddingLeft, defaultValue: 0))
                    }
                }
                Text("Margin")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.muted)
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "Top", value: styleDoubleBinding(\.marginTop, defaultValue: 0))
                        NumberField(label: "Right", value: styleDoubleBinding(\.marginRight, defaultValue: 0))
                    }
                    GridRow {
                        NumberField(label: "Bottom", value: styleDoubleBinding(\.marginBottom, defaultValue: 0))
                        NumberField(label: "Left", value: styleDoubleBinding(\.marginLeft, defaultValue: 0))
                    }
                }
            }
        }
    }

    private var layoutGroup: some View {
        GroupBox("Layout") {
            VStack(alignment: .leading, spacing: 12) {
                styleChoiceRow(
                    title: "Display",
                    value: styleStringBinding(\.display, defaultValue: "block"),
                    options: [
                        StylePresetOption(title: "block", value: "block"),
                        StylePresetOption(title: "flex", value: "flex"),
                        StylePresetOption(title: "grid", value: "grid"),
                        StylePresetOption(title: "inline", value: "inline"),
                        StylePresetOption(title: "none", value: "none")
                    ]
                )
                if model.selectedElement?.style?.display?.contains("flex") == true ||
                   model.selectedElement?.style?.display?.contains("grid") == true {
                    styleChoiceRow(
                        title: "Direction",
                        value: styleStringBinding(\.flexDirection, defaultValue: "row"),
                        options: [
                            StylePresetOption(title: "Row", value: "row"),
                            StylePresetOption(title: "Column", value: "column"),
                            StylePresetOption(title: "Reverse Row", value: "row-reverse"),
                            StylePresetOption(title: "Reverse Column", value: "column-reverse")
                        ]
                    )
                    styleChoiceRow(
                        title: "Main-Axis Alignment",
                        value: styleStringBinding(\.justifyContent, defaultValue: "normal"),
                        options: [
                            StylePresetOption(title: "Start", value: "flex-start"),
                            StylePresetOption(title: "Center", value: "center"),
                            StylePresetOption(title: "End", value: "flex-end"),
                            StylePresetOption(title: "Space Between", value: "space-between"),
                            StylePresetOption(title: "Space Around", value: "space-around")
                        ]
                    )
                    styleChoiceRow(
                        title: "Cross Axis",
                        value: styleStringBinding(\.alignItems, defaultValue: "normal"),
                        options: [
                            StylePresetOption(title: "Start", value: "flex-start"),
                            StylePresetOption(title: "Center", value: "center"),
                            StylePresetOption(title: "End", value: "flex-end"),
                            StylePresetOption(title: "Stretch", value: "stretch"),
                            StylePresetOption(title: "Baseline", value: "baseline")
                        ]
                    )
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            NumberField(label: "Gap", value: styleDoubleBinding(\.gap, defaultValue: 0))
                        }
                    }
                    styleChoiceRow(
                        title: "Wrapping",
                        value: styleStringBinding(\.flexWrap, defaultValue: "nowrap"),
                        options: [
                            StylePresetOption(title: "No Wrap", value: "nowrap"),
                            StylePresetOption(title: "Wrap", value: "wrap"),
                            StylePresetOption(title: "Reverse", value: "wrap-reverse")
                        ]
                    )
                }
                styleChoiceRow(
                    title: "Position",
                    value: styleStringBinding(\.position, defaultValue: "static"),
                    options: [
                        StylePresetOption(title: "static", value: "static"),
                        StylePresetOption(title: "relative", value: "relative"),
                        StylePresetOption(title: "absolute", value: "absolute"),
                        StylePresetOption(title: "fixed", value: "fixed"),
                        StylePresetOption(title: "sticky", value: "sticky")
                    ]
                )
                styleChoiceRow(
                    title: "Overflow",
                    value: styleStringBinding(\.overflow, defaultValue: "visible"),
                    options: [
                        StylePresetOption(title: "visible", value: "visible"),
                        StylePresetOption(title: "hidden", value: "hidden"),
                        StylePresetOption(title: "scroll", value: "scroll"),
                        StylePresetOption(title: "auto", value: "auto")
                    ]
                )
            }
        }
    }

    private var miscStyleGroup: some View {
        GroupBox("Other Styles") {
            VStack(alignment: .leading, spacing: 12) {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "Opacity", value: styleDoubleBinding(\.opacity, defaultValue: 1), fractionLength: 2)
                        NumberField(label: "Letter Spacing", value: styleDoubleBinding(\.letterSpacing, defaultValue: 0), fractionLength: 2)
                    }
                }
                styleChoiceRow(
                    title: "Text Decoration",
                    value: styleStringBinding(\.textDecoration, defaultValue: "none"),
                    options: [
                        StylePresetOption(title: "None", value: "none"),
                        StylePresetOption(title: "Underline", value: "underline"),
                        StylePresetOption(title: "Strikethrough", value: "line-through"),
                        StylePresetOption(title: "Overline", value: "overline")
                    ]
                )
                styleChoiceRow(
                    title: "Letter Case",
                    value: styleStringBinding(\.textTransform, defaultValue: "none"),
                    options: [
                        StylePresetOption(title: "None", value: "none"),
                        StylePresetOption(title: "Uppercase", value: "uppercase"),
                        StylePresetOption(title: "Lowercase", value: "lowercase"),
                        StylePresetOption(title: "Capitalize", value: "capitalize")
                    ]
                )
                styleChoiceRow(
                    title: "Whitespace",
                    value: styleStringBinding(\.whiteSpace, defaultValue: "normal"),
                    options: [
                        StylePresetOption(title: "normal", value: "normal"),
                        StylePresetOption(title: "nowrap", value: "nowrap"),
                        StylePresetOption(title: "pre", value: "pre"),
                        StylePresetOption(title: "pre-wrap", value: "pre-wrap")
                    ]
                )
            }
        }
    }

    @ViewBuilder
    private var htmlAssetGroups: some View {
        if model.documentMode == "html" {
            if isTableSelection {
                tableGroup
            }

            if isCellSelection {
                cellStyleGroup
            }
        }
    }

    private var tableGroup: some View {
        GroupBox("Table") {
            tableOperationGrid
        }
    }

    private var tableOperationGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                CommandButton(title: "+ Row", icon: "plus.square", command: "tableAddRowAfter")
                CommandButton(title: "− Row", icon: "minus.square", command: "tableDeleteRow")
            }
            GridRow {
                CommandButton(title: "+ Column", icon: "plus.rectangle.on.rectangle", command: "tableAddColumnAfter")
                CommandButton(title: "− Column", icon: "minus.rectangle", command: "tableDeleteColumn")
            }
        }
    }

    private var cellStyleGroup: some View {
        GroupBox("Cell Style") {
            VStack(spacing: 10) {
                styleColorSwatches(
                    title: "Cell fill",
                    value: styleStringBinding(\.fill, defaultValue: "transparent"),
                    presets: fillColorPresets
                )
                styleColorSwatches(
                    title: "Cell text",
                    value: styleStringBinding(\.color, defaultValue: "#111827"),
                    presets: textColorPresets
                )
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        StyleTextField(label: "Exact fill", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                        StyleTextField(label: "Exact text color", value: styleStringBinding(\.color, defaultValue: "#111827"))
                    }
                    GridRow {
                        StyleTextField(label: "Border", value: styleStringBinding(\.stroke, defaultValue: "transparent"))
                        NumberField(label: "Width", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                    }
                    GridRow {
                        NumberField(label: "Radius", value: styleDoubleBinding(\.radius, defaultValue: 0))
                        StyleTextField(label: "Exact alignment", value: styleStringBinding(\.textAlign, defaultValue: "left"))
                    }
                }

                styleChoiceRow(
                    title: "Cell alignment",
                    value: styleStringBinding(\.textAlign, defaultValue: "left"),
                    options: textAlignmentPresets
                )

                cellActionGrid
            }
        }
    }

    private var cellActionGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                CommandButton(title: "Left", icon: "text.alignleft", command: "cellAlignLeft")
                CommandButton(title: "Center", icon: "text.aligncenter", command: "cellAlignCenter")
                CommandButton(title: "Right", icon: "text.alignright", command: "cellAlignRight")
            }
            GridRow {
                CommandButton(title: "Header", icon: "tablecells.badge.ellipsis", command: "cellStyleHeader")
                CommandButton(title: "Soft", icon: "paintbrush", command: "cellStyleSoft")
            }
        }
    }

    private var layerGroup: some View {
        GroupBox("Arrange") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    CommandButton(title: "Front", icon: "square.3.layers.3d.top.filled", command: "bringToFront")
                    CommandButton(title: "Back", icon: "square.3.layers.3d.down.right", command: "sendToBack")
                }
                GridRow {
                    CommandButton(title: "Forward", icon: "arrow.up.square", command: "bringForward")
                    CommandButton(title: "Backward", icon: "arrow.down.square", command: "sendBackward")
                }
                GridRow {
                    CommandButton(title: "Lock", icon: "lock", command: "toggleLock")
                    CommandButton(title: "Delete", icon: "trash", command: "delete")
                }
                GridRow {
                    CommandButton(title: "Duplicate", icon: "plus.square.on.square", command: "duplicate")
                }
            }
        }
    }

    private var layerStackGroup: some View {
        GroupBox("Objects On This Page") {
            LayerStackList(
                elements: model.currentSlideElements.sorted { left, right in
                    if left.z == right.z { return left.id < right.id }
                    return left.z > right.z
                },
                selectedID: model.selectedElement?.id
            )
        }
    }

    private func alignmentGroup(for element: EditorElement) -> some View {
        GroupBox("Align") {
            VStack(spacing: 8) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "Left", icon: "align.horizontal.left", command: "alignLeft")
                        CommandButton(title: "Center", icon: "align.horizontal.center", command: "alignCenter")
                    }
                    GridRow {
                        CommandButton(title: "Right", icon: "align.horizontal.right", command: "alignRight")
                        CommandButton(title: "V Center", icon: "align.vertical.center", command: "alignMiddle")
                    }
                }

                if element.type == "html-group" || element.type == "deck-group" {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            CommandButton(title: "Same Width", icon: "arrow.left.and.right.square", command: "matchWidth")
                            CommandButton(title: "Same Height", icon: "arrow.up.and.down.square", command: "matchHeight")
                        }
                        GridRow {
                            CommandButton(title: "Distribute H", icon: "arrow.left.and.right", command: "distributeHorizontal")
                            CommandButton(title: "Distribute V", icon: "arrow.up.and.down", command: "distributeVertical")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func htmlSourceSyncGroup(_ element: EditorElement) -> some View {
        if model.documentMode == "html" {
            GroupBox("Source Sync") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(MaterialTheme.primary)
                            .frame(width: 22, height: 22)
                            .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourceSyncTitle(for: element))
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(MaterialTheme.ink)
                            Text(sourceSyncDetail(for: element))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(MaterialTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    if !(element.sourceSnippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let validation = sourceDraftValidation(for: element)

                        if let ancestorItems = element.sourceAncestorItems, ancestorItems.count > 1 {
                            sourceAncestorNavigationGroup(ancestorItems, selectedID: element.id)
                        }

                        ScrollView(.horizontal, showsIndicators: true) {
                            TextEditor(text: $sourceDraft)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MaterialTheme.ink)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 72, maxHeight: 220, alignment: .topLeading)
                        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                                .stroke(MaterialTheme.hairline, lineWidth: 1)
                        )

                        if let backupReminder = model.activeBackupReminderText {
                            sourceBackupReminderBanner(backupReminder)
                        }

                        SourceDraftValidationBadge(validation: validation)

                        if let mappingSummary = validation.mappingSummary, sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (element.sourceSnippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
                            sourceDraftMappingSummaryGroup(mappingSummary)
                        }

                        if let siblingItems = element.sourceSiblingItems, siblingItems.count > 1 {
                            sourceSiblingNavigationGroup(siblingItems, selectedID: element.id)
                        }

                        if let childItems = element.sourceChildItems, !childItems.isEmpty {
                            sourceChildNavigationGroup(childItems)
                        }

                        HStack(spacing: 8) {
                            Button {
                                copySourceSnippet(sourceDraft)
                            } label: {
                                Label("Copy Snippet", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MaterialButtonStyle(compact: true))

                            Button {
                                restoreSourceDraft(for: element)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MaterialButtonStyle(compact: true))
                            .disabled(!canRestoreSourceDraft(for: element))

                            Button {
                                model.applySelectedHTMLSource(sourceDraft)
                            } label: {
                                Label(sourceApplyButtonTitle(validation), systemImage: validation.mappingSummary?.hasStructureRisk == true ? "exclamationmark.triangle" : "checkmark.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MaterialButtonStyle(compact: true))
                            .disabled(!canApplySourceDraft(for: element, validation: validation))

                            Button {
                                model.selectHTMLNode(id: element.id)
                            } label: {
                                Label("Locate", systemImage: "scope")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MaterialButtonStyle(compact: true))
                        }
                    } else {
                        Text("No displayable source snippet has been generated for this object yet.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                    }
                }
            }
        }
    }

    private func sourceBackupReminderBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "externaldrive.badge.timemachine")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(MaterialTheme.primary)
                .frame(width: 18, height: 18)
                .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("Confirm the original backup first")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaterialTheme.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private func sourceAncestorNavigationGroup(_ items: [EditorSourceNodeItem], selectedID: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                Text("Source Path")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(MaterialTheme.muted.opacity(0.70))
                        }

                        sourceAncestorNavigationButton(item, isSelected: item.id == selectedID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private func sourceAncestorNavigationButton(_ item: EditorSourceNodeItem, isSelected: Bool) -> some View {
        Button {
            locateSourceNodeItem(item, statusPrefix: "Located source path")
        } label: {
            Text(item.label.isEmpty ? item.tagName.uppercased() : item.label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white : MaterialTheme.primaryDark)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isSelected ? MaterialTheme.primary : Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : MaterialTheme.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(item.path)
    }

    private func sourceSiblingNavigationGroup(_ items: [EditorSourceNodeItem], selectedID: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                Text("Sibling Objects")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text("\(items.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MaterialTheme.primaryDark)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        sourceSiblingNavigationButton(item, isSelected: item.id == selectedID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private func sourceSiblingNavigationButton(_ item: EditorSourceNodeItem, isSelected: Bool) -> some View {
        Button {
            locateSourceNodeItem(item, statusPrefix: "Located sibling object")
        } label: {
            HStack(spacing: 5) {
                Text(item.tagName.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : MaterialTheme.primaryDark)
                Text(item.label.isEmpty ? item.tagName : item.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? MaterialTheme.primary : Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.clear : MaterialTheme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(item.path)
    }

    private func sourceChildNavigationGroup(_ items: [EditorSourceNodeItem]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                Text("Child Objects")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text("\(items.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MaterialTheme.primaryDark)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 0)
            }

            LazyVStack(spacing: 5) {
                ForEach(items.prefix(8)) { item in
                    sourceChildNavigationRow(item)
                }

                if items.count > 8 {
                    Text("\(items.count - 8) more child object(s)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                }
            }
        }
        .padding(8)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private func sourceChildNavigationRow(_ item: EditorSourceNodeItem) -> some View {
        Button {
            locateSourceNodeItem(item, statusPrefix: "Located child object")
        } label: {
            HStack(alignment: .top, spacing: 7) {
                Text(item.tagName.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MaterialTheme.primaryDark)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(item.label.isEmpty ? item.tagName : item.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MaterialTheme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if item.canEditText == true {
                            Text("Editable")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(MaterialTheme.primaryDark)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(MaterialTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if let preview = item.textPreview, !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(item.path)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MaterialTheme.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "scope")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
            }
            .padding(.leading, CGFloat(max(0, (item.depth ?? 1) - 1)) * 8)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(MaterialTheme.separator, lineWidth: 1)
        )
        .help(item.path)
    }

    private func locateSourceNodeItem(_ item: EditorSourceNodeItem, statusPrefix: String) {
        invalidateSourceDraftValidationPreview()
        model.selectHTMLNode(id: item.id)
        model.status = "\(statusPrefix): \(item.tagName.uppercased())"
    }

    @ViewBuilder
    private var htmlControlsGroup: some View {
        if model.documentMode == "html" {
            GroupBox("State Preview") {
                VStack(alignment: .leading, spacing: 10) {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            pseudoPreviewButton(title: "Normal", icon: "circle", state: "none")
                            pseudoPreviewButton(title: "Hover", icon: "hand.point.up.left", state: "hover")
                            pseudoPreviewButton(title: "Focus", icon: "cursorarrow.rays", state: "focus")
                        }
                    }

                    Text("The preview affects only the selected object. Use it to check pseudo-class styles for buttons, cards, and forms.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GroupBox("Layout Mode") {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "Free", icon: "arrow.up.left.and.arrow.down.right", command: "setLayoutFree")
                        CommandButton(title: "Transform", icon: "move.3d", command: "setLayoutTransform")
                    }
                }
            }

            GroupBox("Insert Elements") {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "Section", icon: "square.dashed", command: "insertDiv")
                        CommandButton(title: "Paragraph", icon: "text.alignleft", command: "insertParagraph")
                    }
                    GridRow {
                        CommandButton(title: "Image", icon: "photo", command: "insertImage")
                        CommandButton(title: "Link", icon: "link", command: "insertLink")
                    }
                    GridRow {
                        CommandButton(title: "Table", icon: "tablecells", command: "insertTable")
                    }
                }
            }

            GroupBox("Hierarchy Navigation") {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "Parent", icon: "arrow.up.to.line", command: "selectParent")
                        CommandButton(title: "Child", icon: "arrow.down.to.line", command: "selectFirstChild")
                    }
                    GridRow {
                        CommandButton(title: "Previous", icon: "arrow.left.to.line", command: "selectPreviousSibling")
                        CommandButton(title: "Next", icon: "arrow.right.to.line", command: "selectNextSibling")
                    }
                    GridRow {
                        CommandButton(title: "Children", icon: "square.grid.2x2", command: "selectVisibleChildren")
                        CommandButton(title: "Similar", icon: "rectangle.on.rectangle", command: "selectSameClass")
                    }
                    GridRow {
                        CommandButton(title: "Clear", icon: "xmark.square", command: "clearSelection")
                    }
                }
            }
        } else {
            Text("HTML tools are available only in HTML document mode.")
                .font(.callout)
                .foregroundStyle(MaterialTheme.muted)
                .materialCard()
        }
    }

    private func pseudoPreviewButton(title: String, icon: String, state: String) -> some View {
        let isSelected = htmlPseudoPreviewState == state
        return Button {
            htmlPseudoPreviewState = state
            model.setHTMLPseudoPreviewState(state)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MaterialButtonStyle(filled: isSelected, compact: true))
    }

    private var selectedTagName: String {
        model.selectedElement?.tagName?.lowercased() ?? ""
    }

    private var selectedGeometryMetrics: GeometryMetrics? {
        guard let element = model.selectedElement else { return nil }
        let frame = element.frame ?? selectedCanvasFrame
        guard let frame else { return nil }
        return GeometryMetrics(element: element, frame: frame)
    }

    private var selectedCanvasFrame: EditorElementFrame? {
        if let canvas = model.deck?.canvas {
            return EditorElementFrame(label: "Canvas", x: 0, y: 0, w: canvas.width, h: canvas.height)
        }

        if model.documentMode == "html", let element = model.selectedElement {
            return EditorElementFrame(label: "Canvas", x: 0, y: 0, w: max(element.x + element.w, element.w), h: max(element.y + element.h, element.h))
        }

        return nil
    }

    private func copyGeometrySummary(_ metrics: GeometryMetrics) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(metrics.summary, forType: .string)
        model.status = "Copied geometry review details"
    }

    private func copySourceSnippet(_ snippet: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        model.status = "Copied the source snippet for the selected object"
    }

    private func restoreSourceDraft(for element: EditorElement) {
        let snippet = element.sourceSnippet ?? ""
        invalidateSourceDraftValidationPreview()
        sourceDraft = snippet
        sourceDraftElementID = element.id
        sourceDraftOriginalSnippet = snippet
        model.status = "Restored the original source snippet for the selected object"
    }

    private func canRestoreSourceDraft(for element: EditorElement) -> Bool {
        let original = element.sourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let draft = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !original.isEmpty && draft != original
    }

    private func canApplySourceDraft(for element: EditorElement) -> Bool {
        canApplySourceDraft(for: element, validation: sourceDraftValidation(for: element))
    }

    private func canApplySourceDraft(for element: EditorElement, validation: SourceDraftValidation) -> Bool {
        let original = element.sourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let draft = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !draft.isEmpty && draft != original && validation.severity != .error
    }

    private func syncStylesheetRuleDraft(for element: EditorElement) {
        let snippet = element.style?.writebackRuleSnippet ?? ""
        guard !snippet.isEmpty else {
            stylesheetRuleDraft = ""
            stylesheetRuleDraftElementID = nil
            stylesheetRuleOriginalSnippet = ""
            stylesheetRuleValidationMessage = nil
            stylesheetRuleValidationTask?.cancel()
            return
        }

        guard stylesheetRuleDraftElementID != element.id else {
            if stylesheetRuleOriginalSnippet != snippet {
                stylesheetRuleOriginalSnippet = snippet
                stylesheetRuleDraft = snippet
                stylesheetRuleValidationMessage = nil
            } else if stylesheetRuleDraft.isEmpty {
                stylesheetRuleDraft = snippet
            }
            return
        }

        stylesheetRuleDraftElementID = element.id
        stylesheetRuleOriginalSnippet = snippet
        stylesheetRuleDraft = snippet
        stylesheetRuleValidationMessage = nil
        stylesheetRuleValidationTask?.cancel()
    }

    private func restoreStylesheetRuleDraft(for style: EditorElementStyle) {
        let snippet = style.writebackRuleSnippet ?? ""
        stylesheetRuleValidationTask?.cancel()
        stylesheetRuleDraft = snippet
        stylesheetRuleOriginalSnippet = snippet
        stylesheetRuleValidationMessage = nil
        model.status = "Current CSS rule snippet restored"
    }

    private func canRestoreStylesheetRuleDraft(for style: EditorElementStyle) -> Bool {
        let original = (style.writebackRuleSnippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = stylesheetRuleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !original.isEmpty && draft != original
    }

    private func canApplyStylesheetRuleDraft(for style: EditorElementStyle) -> Bool {
        let original = (style.writebackRuleSnippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = stylesheetRuleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !draft.isEmpty && draft != original && stylesheetRuleValidationMessage == nil
    }

    private func scheduleStylesheetRuleValidation(for element: EditorElement) {
        let original = (element.style?.writebackRuleSnippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = stylesheetRuleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        stylesheetRuleValidationTask?.cancel()

        guard !draft.isEmpty, draft != original else {
            stylesheetRuleValidationMessage = nil
            return
        }

        stylesheetRuleValidationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            model.validateSelectedStylesheetRuleDraft(stylesheetRuleDraft) { message in
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    stylesheetRuleValidationMessage = message
                }
            }
        }
    }

    private func sourceDraftValidation(for element: EditorElement) -> SourceDraftValidation {
        SourceDraftValidation(
            original: element.sourceSnippet ?? "",
            draft: sourceDraft,
            originalTagName: element.tagName,
            mappingSummary: model.sourceDraftMappingSummary
        )
    }

    private func scheduleSourceDraftValidationPreview(for element: EditorElement, delay: UInt64 = 250_000_000) {
        sourceDraftValidationTask?.cancel()
        let draft = sourceDraft
        sourceDraftValidationTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            refreshSourceDraftValidationPreview(for: element, draft: draft)
        }
    }

    private func refreshSourceDraftValidationPreview(for element: EditorElement) {
        refreshSourceDraftValidationPreview(for: element, draft: sourceDraft)
    }

    private func refreshSourceDraftValidationPreview(for element: EditorElement, draft: String) {
        guard model.documentMode == "html" else { return }

        let original = element.sourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty, trimmedDraft != original else {
            model.sourceDraftMappingSummary = nil
            return
        }

        let validationID = UUID()
        pendingSourceDraftValidationID = validationID
        model.validateSelectedHTMLSourceDraft(draft) { summary in
            guard pendingSourceDraftValidationID == validationID else { return }
            model.sourceDraftMappingSummary = summary
        }
    }

    private func invalidateSourceDraftValidationPreview() {
        sourceDraftValidationTask?.cancel()
        pendingSourceDraftValidationID = UUID()
        model.sourceDraftMappingSummary = nil
    }

    private func sourceSyncTitle(for element: EditorElement) -> String {
        let tag = element.tagName?.uppercased() ?? "HTML"
        return "\(tag) source snippet"
    }

    private func sourceSyncDetail(for element: EditorElement) -> String {
        let lineCount = element.sourceSnippetLineCount ?? 0
        let linePart = lineCount > 0 ? "\(lineCount) line(s)" : "current object"
        let path = element.htmlPath ?? model.selectionPath
        if let path, !path.isEmpty {
            return "\(linePart), synced with the selected object: \(path)"
        }
        return "\(linePart), synced with the selected object."
    }

    private func sourceDraftMappingSummaryGroup(_ summary: SourceDraftMappingSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                Text("Object Mapping Preview")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
                Text("Preserved \(summary.preservedCount) · Added \(summary.addedCount) · Replaced \(summary.unmatchedCount)")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(summary.hasStructureRisk ? MaterialTheme.accentWarning : MaterialTheme.muted)
            }

            Text(summary.riskSummary)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(summary.hasStructureRisk ? MaterialTheme.accentWarning : MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(sourceDraftMappingPreviewItems(summary)) { item in
                sourceDraftMappingRow(item)
            }

            if summary.items.count > 6 {
                Text("The remaining \(summary.items.count - 6) mapping(s) are collapsed. You can still step through them after applying.")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
            }
        }
        .padding(8)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private func sourceDraftMappingPreviewItems(_ summary: SourceDraftMappingSummary) -> [SourceDraftMappingItem] {
        Array(summary.items.sorted { left, right in
            if sourceDraftMappingPriority(left) == sourceDraftMappingPriority(right) {
                return left.id < right.id
            }
            return sourceDraftMappingPriority(left) < sourceDraftMappingPriority(right)
        }.prefix(6))
    }

    private func sourceDraftMappingPriority(_ item: SourceDraftMappingItem) -> Int {
        switch item.slot {
        case "unmatched": return 0
        case "added": return 1
        default: return 2
        }
    }

    private func sourceDraftMappingRow(_ item: SourceDraftMappingItem) -> some View {
        Button {
            locateSourceDraftMappingItem(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(item.kindDisplay)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(sourceDraftMappingColor(for: item))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(sourceDraftMappingColor(for: item).opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    if let previousLabel = item.previousLabel, !previousLabel.isEmpty {
                        Text(previousLabel)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MaterialTheme.muted)
                    }

                    if !item.nextLabel.isEmpty {
                        Text(item.nextLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(MaterialTheme.ink)
                    } else if item.slot == "unmatched" {
                        Text("This original object has no stable counterpart in the new snippet.")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MaterialTheme.ink)
                    }
                }

                Spacer(minLength: 0)

                if let score = item.score {
                    Text("\(score)")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Image(systemName: sourceDraftMappingCanLocate(item) ? "scope" : "plus.app")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(sourceDraftMappingCanLocate(item) ? MaterialTheme.primary : MaterialTheme.muted.opacity(0.70))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!sourceDraftMappingCanLocate(item))
        .help(sourceDraftMappingCanLocate(item) ? "Locate the current live object" : "Added objects can only be located after applying")
    }

    private func sourceDraftMappingColor(for item: SourceDraftMappingItem) -> Color {
        switch item.slot {
        case "preserved":
            return MaterialTheme.accentSuccess
        case "added":
            return MaterialTheme.primary
        default:
            return MaterialTheme.accentWarning
        }
    }

    private func sourceDraftMappingCanLocate(_ item: SourceDraftMappingItem) -> Bool {
        guard let previousID = item.previousID, !previousID.isEmpty else { return false }
        return item.slot == "preserved" || item.slot == "unmatched"
    }

    private func sourceApplyButtonTitle(_ validation: SourceDraftValidation) -> String {
        validation.mappingSummary?.hasStructureRisk == true ? "Review and Apply" : "Apply Source"
    }

    private func locateSourceDraftMappingItem(_ item: SourceDraftMappingItem) {
        guard sourceDraftMappingCanLocate(item), let previousID = item.previousID else {
            model.status = "Added objects can only be located after the source is applied"
            return
        }

        invalidateSourceDraftValidationPreview()
        model.selectHTMLNode(id: previousID)
        model.status = item.slot == "unmatched" ? "Located the original object that will be replaced" : "Located the original object that will be preserved"
    }

    private func formatMetric(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private var isSelectedImage: Bool {
        selectedTagName == "img" || model.selectedElement?.type == "image" || (model.selectedElement?.semanticRole == "image" && model.selectedElement?.imageSource != nil)
    }

    private func supportsLinkAttributes(_ element: EditorElement) -> Bool {
        selectedTagName == "a" || element.semanticRole == "link" || element.linkHref != nil || element.linkTarget != nil
    }

    private func canApplyHTMLAttributeDrafts(for element: EditorElement) -> Bool {
        let classChanged = classNameDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (element.className ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let styleChanged = inlineStyleDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (element.inlineStyle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let linkChanged = supportsLinkAttributes(element)
            && (
                linkHrefDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (element.linkHref ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                || linkTargetDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (element.linkTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        return classChanged || styleChanged || linkChanged
    }

    private var isCellSelection: Bool {
        selectedTagName == "td" || selectedTagName == "th"
    }

    private var isGeometryLockedSelection: Bool {
        model.documentMode == "html" && model.selectedElement?.editability == "table-structure"
    }

    private var isTableSelection: Bool {
        ["table", "thead", "tbody", "tfoot", "tr", "td", "th", "caption"].contains(selectedTagName)
    }

    private func supportsTextControls(_ element: EditorElement) -> Bool {
        if element.type == "text" { return true }
        return ["h1", "h2", "h3", "h4", "h5", "h6", "p", "span", "li", "button", "a", "label", "td", "th", "caption"].contains(selectedTagName)
    }

    private func supportsImageControls(_ element: EditorElement) -> Bool {
        element.semanticRole != "image-reference" && (element.type == "image" || selectedTagName == "img" || element.imageSource?.isEmpty == false)
    }

    private var textAlignmentPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "Left", value: "left", icon: "text.alignleft"),
            StylePresetOption(title: "Center", value: "center", icon: "text.aligncenter"),
            StylePresetOption(title: "Right", value: "right", icon: "text.alignright")
        ]
    }

    private var imageFitPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "Crop", value: "cover", icon: "crop"),
            StylePresetOption(title: "Fit", value: "contain", icon: "rectangle.dashed"),
            StylePresetOption(title: "Stretch", value: "fill", icon: "arrow.left.and.right")
        ]
    }

    private var shadowPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "None", value: "none", icon: "circle.slash"),
            StylePresetOption(title: "Soft", value: "0 10px 24px rgba(15, 23, 42, 0.16)", icon: "square"),
            StylePresetOption(title: "Strong", value: "0 18px 44px rgba(15, 23, 42, 0.24)", icon: "square.fill")
        ]
    }

    private var textColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "Dark", value: "#111827"),
            StyleColorPreset(title: "Gray", value: "#4b5563"),
            StyleColorPreset(title: "Blue", value: "#0a84ff"),
            StyleColorPreset(title: "Red", value: "#c0262d"),
            StyleColorPreset(title: "White", value: "#ffffff")
        ]
    }

    private var fillColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "Transparent", value: "transparent"),
            StyleColorPreset(title: "White", value: "#ffffff"),
            StyleColorPreset(title: "Light Gray", value: "#f3f6fb"),
            StyleColorPreset(title: "Light Blue", value: "#e8f3ff"),
            StyleColorPreset(title: "Light Green", value: "#eaf7ef"),
            StyleColorPreset(title: "Light Yellow", value: "#fff6d8")
        ]
    }

    private var strokeColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "Transparent", value: "transparent"),
            StyleColorPreset(title: "Light Gray", value: "#d9e1e8"),
            StyleColorPreset(title: "Dark Gray", value: "#6b7280"),
            StyleColorPreset(title: "Blue", value: "#0a84ff"),
            StyleColorPreset(title: "Red", value: "#c0262d")
        ]
    }

    private func styleChoiceRow(title: String, value: Binding<String>, options: [StylePresetOption]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            HStack(spacing: 8) {
                ForEach(options) { option in
                    StyleChoiceButton(option: option, selection: value)
                }
            }
        }
    }

    private func styleColorSwatches(title: String, value: Binding<String>, presets: [StyleColorPreset]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 34, maximum: 38), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(presets) { preset in
                    StyleSwatchButton(preset: preset, selection: value)
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<EditorElement, Double>) -> Binding<Double> {
        Binding {
            model.selectedElement?[keyPath: keyPath] ?? 0
        } set: { value in
            guard var element = model.selectedElement else { return }
            element[keyPath: keyPath] = value
            model.updateElement(element)
        }
    }

    private func styleDoubleBinding(_ keyPath: WritableKeyPath<EditorElementStyle, Double?>, defaultValue: Double) -> Binding<Double> {
        Binding {
            model.selectedElement?.style?[keyPath: keyPath] ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            var style = element.style ?? .empty
            style[keyPath: keyPath] = value
            element.style = style
            model.updateElement(element)
        }
    }

    private func styleStringBinding(_ keyPath: WritableKeyPath<EditorElementStyle, String?>, defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.style?[keyPath: keyPath] ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            var style = element.style ?? .empty
            style[keyPath: keyPath] = value.isEmpty ? nil : value
            element.style = style
            model.updateElement(element)
        }
    }

    private func textContentBinding(defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.text ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            element.text = value
            model.updateElement(element)
        }
    }

    private func imageSourceBinding(defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.imageSource ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            element.imageSource = value.isEmpty ? nil : value
            model.updateElement(element)
        }
    }

    private func imageAltBinding(defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.imageAlt ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            element.imageAlt = value.isEmpty ? nil : value
            model.updateElement(element)
        }
    }
}

private struct InspectorSelectionHeader: View {
    var element: EditorElement
    var path: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MaterialTheme.primary)
                .frame(width: 30, height: 30)
                .background(MaterialTheme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                    Text(element.chiseloTypeLabel)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(MaterialTheme.primaryDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
                }

                Text("\(Int(element.w)) x \(Int(element.h))  ·  X \(Int(element.x)), Y \(Int(element.y))")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.muted)

                if let actionHint {
                    Text(actionHint)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(MaterialTheme.primaryDark)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private var title: String {
        element.chiseloDisplayTitle
    }

    private var iconName: String {
        element.chiseloIconName
    }

    private var actionHint: String? {
        if element.type == "html-group" || element.type == "deck-group" {
            return "A group of objects is selected. You can move, align, or distribute the group."
        }
        if element.imageSource?.isEmpty == false || element.semanticRole == "image" {
            return "You can move, resize, replace, or adjust the image."
        }
        if element.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "You can edit text, move, resize, and adjust the appearance."
        }
        if let path, !path.isEmpty {
            return "The source path is available on the Source tab. This tab contains common edits."
        }
        return nil
    }
}

private struct SourceWritebackStatusBadge: View {
    var status: EditorElementStyle.WritebackStatus

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(status.color)
                .frame(width: 18, height: 18)
                .background(status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(status.title)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    if let target = status.target {
                        Text(target)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(status.color)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let sourceLabel = status.sourceLabel {
                    HStack(spacing: 5) {
                        Image(systemName: status.sourceKind == "linked-local" ? "externaldrive" : "text.alignleft")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(status.color)
                        Text(sourceLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(status.color)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Text(status.detail)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct SourceDraftValidationBadge: View {
    var validation: SourceDraftValidation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: validation.icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(validation.color)
                .frame(width: 18, height: 18)
                .background(validation.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(validation.title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(validation.detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let changeSummary = validation.changeSummary {
                    Text(changeSummary)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(validation.color)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(validation.color.opacity(0.07), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct SourceDraftValidation: Equatable {
    enum Severity {
        case ok
        case warning
        case error
    }

    var severity: Severity
    var messages: [String]
    var changeSummary: String?
    var mappingSummary: SourceDraftMappingSummary?

    init(original: String, draft: String, originalTagName: String?, mappingSummary: SourceDraftMappingSummary? = nil) {
        let originalText = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages: [String] = []
        var severity: Severity = .ok
        let changeSummary = Self.changeSummary(original: originalText, draft: draftText)
        self.mappingSummary = mappingSummary

        if draftText.isEmpty {
            self.severity = .error
            self.messages = ["The source snippet is empty."]
            self.changeSummary = changeSummary
            return
        }

        let lowercasedDraft = draftText.lowercased()
        let blockedPatterns = [
            "<script",
            "<style",
            "<link",
            "<meta",
            "<base",
            "<object",
            "<embed",
            " javascript:",
            "\"javascript:",
            "'javascript:",
            " onload=",
            " onclick=",
            " onerror=",
            " onmouseover="
        ]
        if blockedPatterns.contains(where: { lowercasedDraft.contains($0) }) {
            severity = .error
            messages.append("Contains scripts, stylesheets, embedded objects, or event attributes and cannot be applied directly.")
        }

        let originalTag = Self.firstTagName(in: originalText)
        let draftTag = Self.firstTagName(in: draftText)
        if let originalTag, let draftTag, originalTag != draftTag {
            severity = severity == .error ? .error : .warning
            messages.append("The top-level tag will change from <\(originalTag)> to <\(draftTag)>.")
        } else if let originalTagName, let draftTag, !originalTagName.isEmpty, originalTagName.lowercased() != draftTag {
            severity = severity == .error ? .error : .warning
            messages.append("The top-level tag will change from <\(originalTagName.lowercased())> to <\(draftTag)>.")
        }

        if Self.attributeValue("id", in: originalText) != Self.attributeValue("id", in: draftText) {
            severity = severity == .error ? .error : .warning
            messages.append("The ID will change, which may affect CSS or script targeting.")
        }

        if Self.normalizedClassValue(in: originalText) != Self.normalizedClassValue(in: draftText) {
            severity = severity == .error ? .error : .warning
            messages.append("The class will change, which may affect which styles apply.")
        }

        if let mappingSummary {
            if mappingSummary.hasStructureRisk {
                severity = severity == .error ? .error : .warning
                messages.append(mappingSummary.riskSummary)
            } else if originalText != draftText {
                messages.append(mappingSummary.riskSummary)
            }
        }

        if originalText == draftText {
            messages.append("The source snippet is unchanged.")
        } else if messages.isEmpty {
            messages.append("Structure validation passed. This will replace the selected object.")
        }

        self.severity = severity
        self.messages = Array(NSOrderedSet(array: messages)).compactMap { $0 as? String }
        self.changeSummary = changeSummary
        self.mappingSummary = mappingSummary
    }

    var title: String {
        switch severity {
        case .ok: return "Source validation passed"
        case .warning: return "Review before applying"
        case .error: return "Cannot apply"
        }
    }

    var detail: String {
        messages.prefix(3).joined(separator: " ")
    }

    var icon: String {
        switch severity {
        case .ok: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch severity {
        case .ok: return MaterialTheme.accentSuccess
        case .warning: return MaterialTheme.accentWarning
        case .error: return MaterialTheme.accentDanger
        }
    }

    private static func firstTagName(in html: String) -> String? {
        guard let match = html.range(of: #"<\s*([a-zA-Z][a-zA-Z0-9-]*)"#, options: .regularExpression) else { return nil }
        let token = String(html[match])
        return token
            .replacingOccurrences(of: "<", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map { String($0).lowercased() }
    }

    private static func attributeValue(_ name: String, in html: String) -> String {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(['"])(.*?)\1"#
        guard let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return "" }
        let text = String(html[match])
        guard let separator = text.firstIndex(of: "=") else { return "" }
        return String(text[text.index(after: separator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func normalizedClassValue(in html: String) -> String {
        attributeValue("class", in: html)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.hasPrefix("chiselo") }
            .sorted()
            .joined(separator: " ")
    }

    private static func changeSummary(original: String, draft: String) -> String? {
        guard original != draft else { return nil }

        let originalLines = normalizedLines(original)
        let draftLines = normalizedLines(draft)
        let sharedCount = min(originalLines.count, draftLines.count)
        let changed = (0..<sharedCount).reduce(0) { total, index in
            total + (originalLines[index] == draftLines[index] ? 0 : 1)
        }
        let added = max(0, draftLines.count - originalLines.count)
        let removed = max(0, originalLines.count - draftLines.count)
        let originalStructure = snippetStructure(original)
        let draftStructure = snippetStructure(draft)

        var parts: [String] = []
        if changed > 0 { parts.append("\(changed) line(s) changed") }
        if added > 0 { parts.append("\(added) line(s) added") }
        if removed > 0 { parts.append("\(removed) line(s) removed") }
        if originalStructure.tagCount != draftStructure.tagCount {
            parts.append("tags \(originalStructure.tagCount)->\(draftStructure.tagCount)")
        }
        if originalStructure.childCount != draftStructure.childCount {
            parts.append("children \(originalStructure.childCount)->\(draftStructure.childCount)")
        }

        if parts.isEmpty {
            parts.append("whitespace or indentation changed")
        }
        return parts.joined(separator: ", ")
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func snippetStructure(_ html: String) -> (tagCount: Int, childCount: Int) {
        let regex = try? NSRegularExpression(pattern: #"<\s*/?\s*([a-zA-Z][a-zA-Z0-9-]*)\b[^>]*>"#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let tagTokens = regex?.matches(in: html, range: range).compactMap { match -> String? in
            guard let range = Range(match.range, in: html) else { return nil }
            return String(html[range])
        } ?? []
        let tagCount = tagTokens.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("</") }.count
        let childCount = max(0, topLevelChildStartCount(in: tagTokens) - 1)
        return (tagCount, childCount)
    }

    private static func topLevelChildStartCount(in tagTokens: [String]) -> Int {
        var depth = 0
        var count = 0

        for token in tagTokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            let isClosing = trimmed.hasPrefix("</")
            let isSelfClosing = trimmed.hasSuffix("/>") || isVoidTagToken(trimmed)

            if isClosing {
                depth = max(0, depth - 1)
                continue
            }

            if depth == 1 {
                count += 1
            }

            if !isSelfClosing {
                depth += 1
            }
        }

        return count
    }

    private static func isVoidTagToken(_ token: String) -> Bool {
        guard let tag = firstTagName(in: token) else { return false }
        return ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"].contains(tag)
    }
}

private struct LayerStackList: View {
    var elements: [EditorElement]
    var selectedID: String?

    var body: some View {
        LazyVStack(spacing: 6) {
            if elements.isEmpty {
                Text("This page has no objects.")
                    .font(.callout)
                    .foregroundStyle(MaterialTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(elements) { element in
                    LayerStackRow(element: element, isSelected: element.id == selectedID)
                        .equatable()
                }
            }
        }
    }
}

private struct GroupMembershipBadge: View {
    var element: EditorElement
    var compact: Bool
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: compact ? 8 : 10, weight: .heavy))
            Text(compact ? element.chiseloGroupDisplayLabel : "Module: \(element.chiseloGroupDisplayLabel)")
                .font(.system(size: compact ? 9 : 10, weight: .heavy))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 6)
        .background(background, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var foreground: Color {
        isSelected ? Color.white.opacity(0.90) : MaterialTheme.primaryDark
    }

    private var background: Color {
        isSelected ? Color.white.opacity(0.16) : MaterialTheme.primary.opacity(0.10)
    }
}

private struct LayerStackRow: View, Equatable {
    @EnvironmentObject private var model: EditorModel

    var element: EditorElement
    var isSelected: Bool

    static func == (lhs: LayerStackRow, rhs: LayerStackRow) -> Bool {
        lhs.element == rhs.element && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Button {
            model.selectElement(id: element.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                    .frame(width: 24, height: 24)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if element.locked == true {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .heavy))
                        }
                    }

                    Text("\(Int(element.x)), \(Int(element.y)) · \(Int(element.w)) x \(Int(element.h))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.78) : MaterialTheme.muted)
                        .lineLimit(1)

                    if element.groupLabel != nil || element.groupId != nil {
                        GroupMembershipBadge(element: element, compact: true, isSelected: isSelected)
                    }
                }

                Spacer(minLength: 0)

                Text("Z \(Int(element.z))")
                    .font(.system(size: 9, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : MaterialTheme.primaryDark)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(zBadgeBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isSelected ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
        )
        .help("Select \(title)")
    }

    private var title: String {
        if let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let alt = element.imageAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }

        return element.chiseloTypeLabel
    }

    private var iconName: String {
        element.chiseloIconName
    }

    private var rowBackground: Color {
        isSelected ? MaterialTheme.primary : MaterialTheme.surfaceTint
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.20) : MaterialTheme.primary.opacity(0.10)
    }

    private var zBadgeBackground: Color {
        isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.55)
    }
}

private extension EditorElement {
    typealias EditabilityStatus = (title: String, detail: String, icon: String, color: Color)
    typealias PrecisionSafetyStatus = (title: String, detail: String, operations: [String], targetId: String?, containerId: String?, icon: String, color: Color)

    var chiseloPrecisionSafetyStatus: PrecisionSafetyStatus? {
        if let title = editSafetyTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            let level = editSafetyLevel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "free"
            let detail = editSafetyDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackDetail: String
            switch level {
            case "danger":
                fallbackDetail = "This object has clipping, bounds, or structure risks. Check the parent bounds before moving it."
            case "locked":
                fallbackDetail = "This object is not suitable for direct dragging. Use the related structure tool or select its parent."
            case "caution", "warning":
                fallbackDetail = "The layout or parent container affects this object. Review it after editing."
            default:
                fallbackDetail = "You can move, resize, edit text, and change styles."
            }

            return (
                title,
                detail?.isEmpty == false ? detail! : fallbackDetail,
                editSafetyOperations ?? [],
                editSafetyTargetId,
                editSafetyContainerId,
                precisionSafetyIcon(for: level),
                precisionSafetyColor(for: level)
            )
        }

        if let status = chiseloEditabilityStatus {
            return (
                status.title,
                status.detail,
                [],
                id,
                nil,
                status.icon,
                status.color
            )
        }

        return nil
    }

    var chiseloGeometrySafetyNotice: PrecisionSafetyStatus? {
        let level = editSafetyLevel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard level == "danger" || level == "locked" || level == "caution" || level == "warning" else {
            return nil
        }
        return chiseloPrecisionSafetyStatus
    }

    private func precisionSafetyIcon(for level: String) -> String {
        switch level {
        case "danger":
            return "exclamationmark.triangle.fill"
        case "locked":
            return "lock.fill"
        case "caution", "warning":
            return "hand.raised.fill"
        case "free":
            return "checkmark.seal.fill"
        default:
            return "viewfinder"
        }
    }

    private func precisionSafetyColor(for level: String) -> Color {
        switch level {
        case "danger", "locked":
            return MaterialTheme.accentDanger
        case "caution", "warning":
            return MaterialTheme.accentWarning
        case "free":
            return MaterialTheme.accentSuccess
        default:
            return MaterialTheme.primary
        }
    }

    var chiseloEditabilityStatus: EditabilityStatus? {
        guard editability != nil || fidelity != nil || captureNote != nil else { return nil }

        let note = captureNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch editability ?? "" {
        case "text-editable":
            return ("Editable Text", note?.isEmpty == false ? note! : "Text can be edited directly while its current font, color, and position remain unchanged.", "textformat", MaterialTheme.accentSuccess)
        case "replaceable":
            return ("Replaceable Image", note?.isEmpty == false ? note! : "The image remains a separate object that you can replace and adjust.", "photo", MaterialTheme.accentSuccess)
        case "reference":
            return ("Image Reference", note?.isEmpty == false ? note! : "This is an HTML image reference or placeholder, not a replaceable image node.", "photo", MaterialTheme.accentWarning)
        case "table-structure":
            return ("Table-Internal Object", note?.isEmpty == false ? note! : "You can edit text and styles or use row, column, and cell operations. Select the whole table before moving it.", "tablecells", MaterialTheme.accentDanger)
        case "style-editable":
            return ("Adjustable style object", note?.isEmpty == false ? note! : "The shape, background, or border became an adjustable object.", "square.on.square", MaterialTheme.primary)
        case "whole-object":
            return ("Whole Fidelity Object", note?.isEmpty == false ? note! : "This region cannot be separated reliably. It remains as a whole object.", "rectangle.dashed", MaterialTheme.accentWarning)
        default:
            if fidelity == "approximated" {
                return ("Approximate Reconstruction", note?.isEmpty == false ? note! : "The complex visual effect was converted to an editable approximation.", "wand.and.rays", MaterialTheme.accentWarning)
            }
            return ("Captured object", note?.isEmpty == false ? note! : "Captured from the current rendered page.", "viewfinder", MaterialTheme.primary)
        }
    }

    var chiseloDisplayTitle: String {
        if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let alt = imageAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }

        return chiseloTypeLabel
    }

    var chiseloGroupDisplayLabel: String {
        if let groupLabel = groupLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !groupLabel.isEmpty {
            return groupLabel
        }

        if let groupRole = groupRole?.trimmingCharacters(in: .whitespacesAndNewlines), !groupRole.isEmpty {
            return groupRole
        }

        return "Module"
    }

    var chiseloTypeLabel: String {
        if let semanticLabel, !semanticLabel.isEmpty {
            return semanticLabel
        }

        if semanticRole == "image-reference" {
            return "Image Reference"
        }

        if type == "deck-group" { return "Module Group" }

        switch tagName?.lowercased() {
        case "img":
            return "Image"
        case "table":
            return "Table"
        case "td", "th":
            return "Cell"
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "Heading"
        case "p":
            return "Paragraph"
        case "li":
            return "List Item"
        case "section", "article":
            return "Module"
        case "header":
            return "Header"
        case "footer":
            return "Footer"
        case "group":
            return "Multiple Objects"
        default:
            if type == "text" { return "Text" }
            if type == "image" { return "Image" }
            if type == "html-group" { return "Multiple Objects" }
            if type == "deck-group" { return "Module Group" }
            return "Object"
        }
    }

    var chiseloIconName: String {
        switch semanticRole ?? "" {
        case "heading", "paragraph", "text", "list-item", "caption":
            return "textformat"
        case "image", "image-reference", "figure":
            return "photo"
        case "table", "table-section", "table-row", "table-cell", "table-header-cell", "table-like":
            return "tablecells"
        case "page":
            return "doc"
        case "header":
            return "rectangle.topthird.inset.filled"
        case "footer":
            return "rectangle.bottomthird.inset.filled"
        case "card", "module", "container":
            return "square.3.layers.3d"
        case "module-group":
            return "square.3.layers.3d"
        case "selection-group":
            return "square.grid.2x2"
        case "graphic", "visual":
            return "chart.xyaxis.line"
        case "media":
            return "play.rectangle"
        case "link":
            return "link"
        case "button", "form-control", "form":
            return "slider.horizontal.3"
        default:
            switch type {
            case "text":
                return "textformat"
            case "image":
                return "photo"
            default:
                return tagName?.lowercased() == "img" ? "photo" : "square.on.square"
            }
        }
    }
}

private extension HTMLTreeNode {
    var chiseloTypeLabel: String {
        if let semanticLabel, !semanticLabel.isEmpty {
            return semanticLabel
        }

        if semanticRole == "image-reference" {
            return "Image Reference"
        }

        switch tagName.lowercased() {
        case "img":
            return "Image"
        case "table":
            return "Table"
        case "td", "th":
            return "Cell"
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "Heading"
        case "p":
            return "Paragraph"
        case "li":
            return "List Item"
        case "section", "article":
            return "Module"
        case "header":
            return "Header"
        default:
            return "Object"
        }
    }

    var chiseloIconName: String {
        switch semanticRole ?? "" {
        case "heading", "paragraph", "text", "list-item", "caption":
            return "textformat"
        case "image", "image-reference", "figure":
            return "photo"
        case "table", "table-section", "table-row", "table-cell", "table-header-cell", "table-like":
            return "tablecells"
        case "page":
            return "doc"
        case "header":
            return "rectangle.topthird.inset.filled"
        case "footer":
            return "rectangle.bottomthird.inset.filled"
        case "card", "module", "container":
            return "square.3.layers.3d"
        case "graphic", "visual":
            return "chart.xyaxis.line"
        case "media":
            return "play.rectangle"
        case "link":
            return "link"
        case "button", "form-control", "form":
            return "slider.horizontal.3"
        default:
            return tagName.lowercased() == "img" ? "photo" : "square"
        }
    }
}

private struct StylePresetOption: Identifiable {
    var title: String
    var value: String
    var icon: String?

    var id: String { value }
}

private struct StyleColorPreset: Identifiable {
    var title: String
    var value: String

    var id: String { value }
}

private struct StyleChoiceButton: View {
    var option: StylePresetOption
    @Binding var selection: String

    private var isSelected: Bool {
        selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == option.value.lowercased()
    }

    var body: some View {
        Button {
            selection = option.value
        } label: {
            if let icon = option.icon {
                Label(option.title, systemImage: icon)
                    .frame(maxWidth: .infinity)
            } else {
                Text(option.title)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(MaterialButtonStyle(filled: isSelected, compact: true))
    }
}

private struct StyleSwatchButton: View {
    var preset: StyleColorPreset
    @Binding var selection: String

    private var isSelected: Bool {
        selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == preset.value.lowercased()
    }

    var body: some View {
        Button {
            selection = preset.value
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(swatchFill)
                    .overlay(transparentPattern)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(checkColor)
                }
            }
            .frame(width: 34, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(isSelected ? MaterialTheme.primary : MaterialTheme.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
    }

    private var swatchFill: Color {
        cssColor(preset.value, fallback: MaterialTheme.surfaceTint)
    }

    @ViewBuilder
    private var transparentPattern: some View {
        if preset.value.lowercased() == "transparent" {
            ZStack {
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(MaterialTheme.surfaceStrong)
                Path { path in
                    path.move(to: CGPoint(x: 7, y: 23))
                    path.addLine(to: CGPoint(x: 27, y: 7))
                }
                .stroke(MaterialTheme.accentDanger.opacity(0.65), lineWidth: 2)
            }
        }
    }

    private var checkColor: Color {
        preset.value.lowercased() == "#ffffff" || preset.value.lowercased() == "transparent" ? MaterialTheme.primaryDark : Color.white
    }
}

private struct NumberField: View {
    var label: String
    @Binding var value: Double
    var fractionLength: Int = 0

    @State private var draftValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            TextField(label, text: $draftValue)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MaterialInputBackground())
                .frame(minWidth: 86)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onAppear {
                    draftValue = formatted(value)
                }
                .onChange(of: value) { nextValue in
                    if !isFocused {
                        draftValue = formatted(nextValue)
                    }
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        draftValue = formatted(value)
                    } else {
                        commitDraft()
                    }
                }
        }
    }

    private func commitDraft() {
        let normalized = draftValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let nextValue = Double(normalized), nextValue.isFinite else {
            draftValue = formatted(value)
            return
        }

        if abs(nextValue - value) > 0.0001 {
            value = nextValue
        }
        draftValue = formatted(nextValue)
    }

    private func formatted(_ value: Double) -> String {
        if fractionLength == 0 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.\(fractionLength)f", value)
    }
}

private struct GeometryMetricGrid: View {
    var metrics: GeometryMetrics

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                GeometryMetricCell(title: "Left", value: metrics.left)
                GeometryMetricCell(title: "Top", value: metrics.top)
            }
            GridRow {
                GeometryMetricCell(title: "Right", value: metrics.right)
                GeometryMetricCell(title: "Bottom", value: metrics.bottom)
            }
            GridRow {
                GeometryMetricCell(title: "Center X", value: metrics.centerXOffset, signed: true)
                GeometryMetricCell(title: "Center Y", value: metrics.centerYOffset, signed: true)
            }
        }
    }
}

private struct GeometryMetricCell: View {
    var title: String
    var value: Double
    var signed: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            Spacer(minLength: 6)
            Text(formattedValue)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(value < 0 ? MaterialTheme.accentDanger : MaterialTheme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(value < 0 ? MaterialTheme.accentDanger.opacity(0.45) : MaterialTheme.separator, lineWidth: 1)
        )
    }

    private var formattedValue: String {
        let rounded = Int(value.rounded())
        if signed, rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
    }
}

private struct StyleTextField: View {
    var label: String
    @Binding var value: String

    @State private var draftValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            TextField(label, text: $draftValue)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MaterialInputBackground())
                .frame(minWidth: 86)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onAppear {
                    draftValue = value
                }
                .onChange(of: value) { nextValue in
                    if !isFocused {
                        draftValue = nextValue
                    }
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        draftValue = value
                    } else {
                        commitDraft()
                    }
                }
        }
    }

    private func commitDraft() {
        if draftValue != value {
            value = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private extension EditorElementStyle {
    typealias WritebackStatus = (
        title: String,
        detail: String,
        target: String?,
        sourceLabel: String?,
        sourceKind: String?,
        sourceURL: String?,
        ruleSnippet: String?,
        ruleLine: Int?,
        icon: String,
        color: Color
    )

    var writebackStatus: WritebackStatus? {
        guard let kind = writebackKind?.trimmingCharacters(in: .whitespacesAndNewlines), !kind.isEmpty else {
            return nil
        }

        let target = writebackTarget?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTarget = target?.isEmpty == false ? target : nil
        let detail = writebackDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceLabel = writebackSourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSourceLabel = sourceLabel?.isEmpty == false ? sourceLabel : nil
        let sourceKind = writebackSourceKind?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceURL = writebackSourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSourceURL = sourceURL?.isEmpty == false ? sourceURL : nil
        let ruleSnippet = writebackRuleSnippet?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRuleSnippet = ruleSnippet?.isEmpty == false ? ruleSnippet : nil
        let ruleLine = writebackRuleLine

        if kind == "stylesheet-rule" {
            let selector = normalizedTarget ?? "a CSS rule"
            return (
                "Writes back to CSS rule",
                detail?.isEmpty == false ? detail! : "Safe style changes are written back to \(selector) first.",
                selector,
                normalizedSourceLabel,
                sourceKind,
                normalizedSourceURL,
                normalizedRuleSnippet,
                ruleLine,
                "curlybraces",
                MaterialTheme.accentSuccess
            )
        }

        if kind == "inline-style" {
            return (
                "Writes to object style",
                detail?.isEmpty == false ? detail! : "Style changes are written to this object's inline style.",
                normalizedTarget,
                normalizedSourceLabel,
                sourceKind,
                normalizedSourceURL,
                normalizedRuleSnippet,
                ruleLine,
                "paintbrush.pointed",
                MaterialTheme.accentWarning
            )
        }

        return nil
    }

    static var empty: EditorElementStyle {
        EditorElementStyle(
            fontFamily: nil,
            fontSize: nil,
            fontWeight: nil,
            lineHeight: nil,
            color: nil,
            fill: nil,
            stroke: nil,
            strokeWidth: nil,
            radius: nil,
            shadow: nil,
            textAlign: nil,
            objectFit: nil,
            writebackKind: nil,
            writebackLabel: nil,
            writebackTarget: nil,
            writebackDetail: nil,
            writebackSourceKind: nil,
            writebackSourceLabel: nil,
            writebackSourceURL: nil,
            writebackRuleSnippet: nil,
            writebackRuleLine: nil
        )
    }
}

private struct CommandButton: View {
    @EnvironmentObject private var model: EditorModel

    var title: String
    var icon: String
    var command: String

    var body: some View {
        Button {
            model.editorCommand(command)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MaterialButtonStyle(compact: true))
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack {
            Text(model.status)
                .font(.caption)
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(1)

            if let element = model.selectedElement {
                StatusSelectionSummary(element: element)
            }

            Spacer()

            if model.hasOpenDocument, let canvas = model.deck?.canvas {
                Text("\(Int(canvas.width)) x \(Int(canvas.height))")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.primary)
            } else if model.hasOpenDocument, model.documentMode == "html" {
                Text("HTML Document")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
    }
}

private struct StatusSelectionSummary: View {
    var element: EditorElement

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(MaterialTheme.separator)
                .frame(width: 4, height: 4)
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text("\(title)  \(Int(element.w)) x \(Int(element.h))")
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.leading, 6)
        .accessibilityLabel("Selected \(title), size \(Int(element.w)) x \(Int(element.h))")
    }

    private var title: String {
        element.chiseloTypeLabel
    }

    private var iconName: String {
        element.chiseloIconName
    }
}

private struct MaterialPanelHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(MaterialTheme.ink)
            Text(subtitle)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.7)
                .foregroundStyle(MaterialTheme.primary)
        }
    }
}

private struct MaterialDivider: View {
    var body: some View {
        Rectangle()
            .fill(MaterialTheme.separator)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 2)
    }
}

private struct MaterialSidebarBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                    .fill(MaterialTheme.surfaceChrome)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                    .stroke(MaterialTheme.hairline.opacity(0.78), lineWidth: 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(0.055), radius: 14, x: 0, y: 4)
    }
}

private struct MaterialInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
            .fill(MaterialTheme.surfaceFloating)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(MaterialTheme.separator.opacity(0.82), lineWidth: 1)
            )
    }
}

private struct MaterialGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(MaterialTheme.primary)
            configuration.content
        }
        .padding(MaterialTheme.panelPadding)
        .materialCard()
    }
}

struct MaterialButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var filled: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .bold))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, compact ? 9 : MaterialTheme.panelPadding)
            .padding(.vertical, compact ? 7 : 9)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(backgroundColor)
                    .shadow(
                        color: MaterialTheme.shadow.opacity(shadowOpacity(isPressed: configuration.isPressed)),
                        radius: isEnabled ? (configuration.isPressed ? 2 : 6) : 0,
                        x: 0,
                        y: isEnabled ? (configuration.isPressed ? 1 : 2) : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(filled || !isEnabled ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.56)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return MaterialTheme.muted
        }
        return filled ? Color.white : MaterialTheme.primaryDark
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return MaterialTheme.surfaceChrome.opacity(0.72)
        }
        return filled ? MaterialTheme.primary : MaterialTheme.surfaceFloating
    }

    private func shadowOpacity(isPressed: Bool) -> Double {
        guard isEnabled else { return 0 }
        if filled {
            return isPressed ? 0.10 : 0.16
        }
        return isPressed ? 0.04 : 0.08
    }
}

private struct MaterialCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MaterialTheme.panelPadding)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .fill(.regularMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                            .fill(MaterialTheme.surfaceFloating)
                    )
                    .shadow(color: MaterialTheme.shadow.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.hairline.opacity(0.82), lineWidth: 1)
            )
    }
}

private extension View {
    func materialCard() -> some View {
        modifier(MaterialCardModifier())
    }
}

private func cssLinearGradient(_ value: String?) -> CSSLinearGradient? {
    guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          rawValue.lowercased().hasPrefix("linear-gradient("),
          rawValue.hasSuffix(")") else {
        return nil
    }

    let start = rawValue.index(rawValue.startIndex, offsetBy: "linear-gradient(".count)
    let end = rawValue.index(before: rawValue.endIndex)
    var arguments = splitCSSArguments(String(rawValue[start..<end]))
    guard arguments.count >= 2 else { return nil }

    let direction = gradientDirection(from: arguments[0])
    if direction != nil {
        arguments.removeFirst()
    }

    let rawStops = arguments.compactMap(cssGradientStop)
    guard rawStops.count >= 2 else { return nil }

    let fallbackDenominator = max(1, rawStops.count - 1)
    let stops = rawStops.enumerated().map { index, rawStop in
        Gradient.Stop(
            color: rawStop.color,
            location: CGFloat(rawStop.location ?? Double(index) / Double(fallbackDenominator))
        )
    }

    let points = gradientPoints(for: direction ?? 180)
    return CSSLinearGradient(startPoint: points.start, endPoint: points.end, stops: stops)
}

private func splitCSSArguments(_ value: String) -> [String] {
    var output: [String] = []
    var current = ""
    var depth = 0
    var quote: Character?

    for character in value {
        if let activeQuote = quote {
            current.append(character)
            if character == activeQuote {
                quote = nil
            }
            continue
        }

        if character == "\"" || character == "'" {
            quote = character
            current.append(character)
            continue
        }

        if character == "(" {
            depth += 1
            current.append(character)
            continue
        }

        if character == ")" {
            depth = max(0, depth - 1)
            current.append(character)
            continue
        }

        if character == "," && depth == 0 {
            output.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
            current = ""
            continue
        }

        current.append(character)
    }

    let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty {
        output.append(tail)
    }
    return output
}

private func gradientDirection(from value: String) -> Double? {
    let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lowercased.hasSuffix("deg"),
       let angle = Double(lowercased.dropLast(3).trimmingCharacters(in: .whitespacesAndNewlines)) {
        return angle
    }

    guard lowercased.hasPrefix("to ") else { return nil }
    let tokens = Set(lowercased.dropFirst(3).split(separator: " ").map(String.init))
    switch (tokens.contains("top"), tokens.contains("right"), tokens.contains("bottom"), tokens.contains("left")) {
    case (true, true, false, false):
        return 45
    case (false, true, true, false):
        return 135
    case (false, false, true, true):
        return 225
    case (true, false, false, true):
        return 315
    case (true, false, false, false):
        return 0
    case (false, true, false, false):
        return 90
    case (false, false, true, false):
        return 180
    case (false, false, false, true):
        return 270
    default:
        return nil
    }
}

private func gradientPoints(for angle: Double) -> (start: UnitPoint, end: UnitPoint) {
    let radians = angle * Double.pi / 180
    let dx = sin(radians)
    let dy = -cos(radians)
    let start = UnitPoint(x: clampUnit(0.5 - dx / 2), y: clampUnit(0.5 - dy / 2))
    let end = UnitPoint(x: clampUnit(0.5 + dx / 2), y: clampUnit(0.5 + dy / 2))
    return (start, end)
}

private func clampUnit(_ value: Double) -> Double {
    max(0, min(1, value))
}

private func cssGradientStop(_ value: String) -> (color: Color, location: Double?)? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let colorToken: String
    let remainder: String
    if trimmed.lowercased().hasPrefix("rgb"),
       let close = trimmed.firstIndex(of: ")") {
        colorToken = String(trimmed[...close])
        remainder = String(trimmed[trimmed.index(after: close)...])
    } else {
        let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        colorToken = String(parts.first ?? "")
        remainder = parts.count > 1 ? String(parts[1]) : ""
    }

    let color = cssColor(colorToken, fallback: .clear)
    let position = remainder
        .split(whereSeparator: { $0.isWhitespace || $0 == "," })
        .compactMap { cssStopLocation(String($0)) }
        .first
    return (color, position)
}

private func cssStopLocation(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return clampUnit(percent / 100)
    }

    guard let number = Double(trimmed) else { return nil }
    return clampUnit(number)
}

private func cssColor(_ value: String?, fallback: Color) -> Color {
    guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
        return fallback
    }

    let lowercased = rawValue.lowercased()
    if lowercased == "transparent" || lowercased == "none" {
        return Color.clear
    }

    if let namedColor = namedCSSColor(lowercased) {
        return namedColor
    }

    if lowercased.hasPrefix("#") {
        let hex = String(lowercased.dropFirst())
        return colorFromHex(hex) ?? fallback
    }

    if lowercased.hasPrefix("rgb") {
        return colorFromRGBFunction(lowercased) ?? fallback
    }

    return fallback
}

private func colorFromHex(_ hex: String) -> Color? {
    let expanded: String
    if hex.count == 3 || hex.count == 4 {
        expanded = hex.map { "\($0)\($0)" }.joined()
    } else {
        expanded = hex
    }

    guard expanded.count == 6 || expanded.count == 8,
          let value = Int(expanded, radix: 16) else {
        return nil
    }

    let hasAlpha = expanded.count == 8
    let redShift = hasAlpha ? 24 : 16
    let greenShift = hasAlpha ? 16 : 8
    let blueShift = hasAlpha ? 8 : 0

    let red = Double((value >> redShift) & 0xFF) / 255
    let green = Double((value >> greenShift) & 0xFF) / 255
    let blue = Double((value >> blueShift) & 0xFF) / 255
    let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
    return Color(red: red, green: green, blue: blue, opacity: alpha)
}

private func colorFromRGBFunction(_ value: String) -> Color? {
    guard let open = value.firstIndex(of: "("),
          let close = value.lastIndex(of: ")"),
          open < close else {
        return nil
    }

    let body = value[value.index(after: open)..<close]
    let parts = body
        .split { $0 == "," || $0 == " " || $0 == "/" }
        .map(String.init)
        .filter { !$0.isEmpty }

    guard parts.count >= 3,
          let red = rgbChannel(parts[0]),
          let green = rgbChannel(parts[1]),
          let blue = rgbChannel(parts[2]) else {
        return nil
    }

    let alpha = parts.count >= 4 ? alphaChannel(parts[3]) : 1
    return Color(
        red: red,
        green: green,
        blue: blue,
        opacity: max(0, min(1, alpha))
    )
}

private func rgbChannel(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return max(0, min(1, percent / 100))
    }

    guard let number = Double(trimmed) else { return nil }
    return max(0, min(255, number)) / 255
}

private func alphaChannel(_ value: String) -> Double {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return max(0, min(1, percent / 100))
    }

    return max(0, min(1, Double(trimmed) ?? 1))
}

private func namedCSSColor(_ value: String) -> Color? {
    switch value {
    case "black":
        return .black
    case "white":
        return .white
    case "red":
        return .red
    case "green":
        return .green
    case "blue":
        return .blue
    case "gray", "grey":
        return .gray
    case "yellow":
        return .yellow
    case "orange":
        return .orange
    case "purple":
        return .purple
    case "pink":
        return .pink
    case "brown":
        return .brown
    case "cyan":
        return .cyan
    case "magenta":
        return Color(red: 1, green: 0, blue: 1)
    default:
        return nil
    }
}

private func nsImageFromDataURL(_ value: String?) -> NSImage? {
    guard let value,
          value.lowercased().hasPrefix("data:image"),
          let commaIndex = value.firstIndex(of: ",") else {
        return nil
    }

    let metadata = value[..<commaIndex].lowercased()
    let payload = String(value[value.index(after: commaIndex)...])
    let data: Data?
    if metadata.contains(";base64") {
        data = Data(base64Encoded: payload)
    } else {
        data = payload.removingPercentEncoding?.data(using: .utf8)
    }

    guard let data else { return nil }
    return NSImage(data: data)
}
