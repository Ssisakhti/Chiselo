import SwiftUI

struct HTMLDocumentCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
            .fill(MaterialTheme.surface)
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    Text("HTML")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1.2)
                        .foregroundStyle(MaterialTheme.primary)
                    Text("HTML Page")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(MaterialTheme.ink)
                    Spacer()
                    Text("Select content or structure")
                        .font(.caption2)
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(8),
                alignment: .topLeading
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.primary.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(0.18), radius: 8, x: 0, y: 3)
    }
}

struct HTMLDeliveryCheckCard: View {
    @EnvironmentObject private var model: EditorModel

    var diagnostics: HTMLDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: headerIcon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(headerColor)
                    .frame(width: 22, height: 22)
                    .background(headerColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Delivery Check")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(headerColor)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 7) {
                DeliveryCheckRow(
                    icon: resourceIcon,
                    title: "Resources",
                    detail: resourceDetail,
                    color: resourceColor,
                    isClickable: diagnostics.resourceElementId != nil
                ) {
                    if let elementId = diagnostics.resourceElementId {
                        model.selectHTMLNode(id: elementId)
                    }
                }

                DeliveryCheckRow(
                    icon: diagnostics.cleanExport ? "checkmark.seal" : "exclamationmark.triangle",
                    title: "Source Cleanliness",
                    detail: diagnostics.sourceCleanlinessDetail,
                    color: diagnostics.cleanExport ? successColor : MaterialTheme.accentDanger,
                    isClickable: false
                )

                if (diagnostics.visualChangeCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "rectangle.2.swap",
                        title: "Visual Changes",
                        detail: "\(diagnostics.visualChangeCount ?? 0) objects changed since opening",
                        color: warningColor,
                        isClickable: !diagnostics.visualChangeTargetIds.isEmpty
                    ) {
                        if let elementId = diagnostics.visualChangeTargetIds.first {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.runtimeCompatibilityRiskCount > 0 {
                    DeliveryCheckRow(
                        icon: "wand.and.rays",
                        title: "Dynamic Content Risk",
                        detail: diagnostics.runtimeCompatibilityDetail,
                        color: warningColor,
                        isClickable: diagnostics.runtimeRiskElementId != nil
                    ) {
                        if let elementId = diagnostics.runtimeRiskElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.responsiveLayoutRiskCount ?? 0 > 0 {
                    DeliveryCheckRow(
                        icon: "rectangle.split.3x1",
                        title: "Multi-Width Review",
                        detail: diagnostics.responsiveReviewDetail,
                        color: warningColor,
                        isClickable: false
                    )
                }

                if diagnostics.precisionEditingRiskCount > 0 {
                    DeliveryCheckRow(
                        icon: "crop",
                        title: "Editing Structure",
                        detail: diagnostics.precisionEditingRiskDetail,
                        color: warningColor,
                        isClickable: diagnostics.precisionEditingRiskElementId != nil
                    ) {
                        if let elementId = diagnostics.precisionEditingRiskElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if model.workspaceMode == .advanced, diagnostics.sourcePollutionReviewCount > 0 {
                    DeliveryCheckRow(
                        icon: "curlybraces.square",
                        title: "Source Review",
                        detail: diagnostics.sourcePollutionReviewDetail,
                        color: warningColor,
                        isClickable: !diagnostics.sourceWritebackTargetIds.isEmpty
                    ) {
                        if let elementId = diagnostics.sourceWritebackTargetIds.first {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.tableCount > 0 {
                    DeliveryCheckRow(
                        icon: diagnostics.spanTableCount > 0 ? "tablecells.badge.ellipsis" : "tablecells",
                        title: "Tables",
                        detail: diagnostics.spanTableCount > 0 ? "\(diagnostics.tableCount) tables; \(diagnostics.spanTableCount) contain merged cells" : "\(diagnostics.tableCount) tables",
                        color: diagnostics.spanTableCount > 0 ? warningColor : successColor,
                        isClickable: diagnostics.tableElementId != nil
                    ) {
                        if let elementId = diagnostics.tableElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.svgCount > 0 {
                    DeliveryCheckRow(
                        icon: "scribble.variable",
                        title: "SVG",
                        detail: "\(diagnostics.svgCount) SVG or vector graphics",
                        color: warningColor,
                        isClickable: diagnostics.svgElementId != nil
                    ) {
                        if let elementId = diagnostics.svgElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.textOverflowCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "text.badge.exclamationmark",
                        title: "Text",
                        detail: "\(diagnostics.textOverflowCount ?? 0) text overflow issues",
                        color: MaterialTheme.accentDanger,
                        isClickable: diagnostics.textOverflowElementId != nil
                    ) {
                        if let elementId = diagnostics.textOverflowElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.outOfBoundsCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "Bounds",
                        detail: "\(diagnostics.outOfBoundsCount ?? 0) elements extend beyond the page",
                        color: MaterialTheme.accentDanger,
                        isClickable: diagnostics.outOfBoundsElementId != nil
                    ) {
                        if let elementId = diagnostics.outOfBoundsElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.clippedGeometryCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "crop",
                        title: "Clipping",
                        detail: "\(diagnostics.clippedGeometryCount ?? 0) objects are clipped by parent overflow",
                        color: MaterialTheme.accentDanger,
                        isClickable: diagnostics.clippedGeometryElementId != nil
                    ) {
                        if let elementId = diagnostics.clippedGeometryElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.overlapCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "square.stack.3d.up",
                        title: "Overlap",
                        detail: "\(diagnostics.overlapCount ?? 0) clear overlaps",
                        color: warningColor,
                        isClickable: diagnostics.overlapElementId != nil
                    ) {
                        if let elementId = diagnostics.overlapElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }
            }

            if !visibleIssues.isEmpty {
                Divider()
                    .overlay(MaterialTheme.hairline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Issue Navigation")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)

                    ForEach(visibleIssues) { issue in
                        DeliveryIssueRow(issue: issue) {
                            if let elementId = issue.elementId {
                                model.selectHTMLNode(id: elementId)
                            }
                        } relatedAction: {
                            if let elementId = issue.relatedElementId {
                                model.selectHTMLNode(id: elementId)
                            }
                        }
                    }

                    if hiddenIssueCount > 0 {
                        Text("\(hiddenIssueCount) more items will appear after you resolve the current items")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding(12)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    private var headerIcon: String {
        diagnostics.issueCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private var headerSubtitle: String {
        if diagnostics.issueCount > 0 { return "\(diagnostics.issueCount) risks" }
        if diagnostics.warningCount > 0 { return "\(diagnostics.warningCount) notices" }
        return "Ready for Delivery"
    }

    private var headerColor: Color {
        if diagnostics.issueCount > 0 { return MaterialTheme.accentDanger }
        if diagnostics.warningCount > 0 { return warningColor }
        return successColor
    }

    private var resourceIcon: String {
        diagnostics.brokenImages + diagnostics.brokenMedia > 0 ? "photo.badge.exclamationmark" : "photo.on.rectangle"
    }

    private var resourceDetail: String {
        let broken = diagnostics.brokenImages + diagnostics.brokenMedia
        if broken > 0 {
            return "\(diagnostics.brokenImages) broken images and \(diagnostics.brokenMedia) broken media items"
        }

        let embedded = diagnostics.embeddedImages ?? 0
        if diagnostics.imageCount == 0 && diagnostics.mediaCount == 0 { return "No external images or media" }
        if embedded > 0 { return "\(diagnostics.imageCount) images; \(embedded) embedded" }
        return "\(diagnostics.imageCount) images and \(diagnostics.mediaCount) media items"
    }

    private var resourceColor: Color {
        diagnostics.brokenImages + diagnostics.brokenMedia > 0 ? MaterialTheme.accentDanger : successColor
    }

    private var successColor: Color {
        MaterialTheme.accentSuccess
    }

    private var warningColor: Color {
        MaterialTheme.accentWarning
    }

    private var visibleIssues: [HTMLDiagnosticIssue] {
        Array((diagnostics.issues ?? []).prefix(5))
    }

    private var hiddenIssueCount: Int {
        max(0, (diagnostics.issues ?? []).count - visibleIssues.count)
    }
}

struct DeliveryCheckRow: View {
    var icon: String
    var title: String
    var detail: String
    var color: Color
    var isClickable: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(detail)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                if isClickable {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(MaterialTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isClickable)
        .opacity(isClickable ? 1 : 0.88)
    }
}

struct DeliveryIssueRow: View {
    var issue: HTMLDiagnosticIssue
    var action: () -> Void
    var relatedAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(issue.title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                    .lineLimit(1)
                Text(issue.detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if issue.elementId != nil {
                    Button(action: action) {
                        Image(systemName: "scope")
                            .font(.system(size: 9, weight: .heavy))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MaterialTheme.primary)
                    .help("Locate the affected object")
                }

                if issue.relatedElementId != nil {
                    Button {
                        relatedAction?()
                    } label: {
                        Image(systemName: "rectangle.inset.filled")
                            .font(.system(size: 9, weight: .heavy))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MaterialTheme.accentWarning)
                    .help("Locate the related parent")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(issue.elementId == nil ? 0.72 : 1)
    }

    private var icon: String {
        switch issue.kind {
        case "broken-image", "broken-media":
            return "photo.badge.exclamationmark"
        case "text-overflow":
            return "text.badge.exclamationmark"
        case "out-of-bounds":
            return "arrow.up.left.and.arrow.down.right"
        case "clipped-geometry", "clip-container-risk", "table-clip-risk":
            return "crop"
        case "overlap":
            return "square.stack.3d.up"
        case "span-table":
            return "tablecells.badge.ellipsis"
        case "pptx-effect-risk":
            return "camera.filters"
        case "visual-change":
            return "rectangle.2.swap"
        case "responsive-review":
            return "rectangle.split.3x1"
        case "source-pollution-review", "stylesheet-edit-review":
            return "curlybraces.square"
        case "runtime-rendered", "external-runtime-resource":
            return "wand.and.rays"
        case "iframe-content":
            return "rectangle.inset.filled"
        case "canvas-content":
            return "square.dashed"
        case "shadow-content":
            return "shippingbox"
        case "selection-overlay":
            return "rectangle.stack.badge.minus"
        default:
            return issue.severity == "error" ? "exclamationmark.triangle" : "info.circle"
        }
    }

    private var color: Color {
        issue.severity == "error" ? MaterialTheme.accentDanger : MaterialTheme.accentWarning
    }
}
