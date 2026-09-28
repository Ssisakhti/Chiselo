import Foundation

extension HTMLDiagnostics {
    var ordinaryPreflightSummary: String {
        if blockingExportRiskCount > 0 {
            return "\(blockingExportRiskCount) items require attention"
        }
        if (visualChangeCount ?? 0) > 0 {
            return "\(visualChangeCount ?? 0) visual changes require review"
        }
        return "HTML and PDF are ready for export review"
    }

    var ordinaryPreflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if (visualChangeCount ?? 0) > 0 { return "rectangle.2.swap" }
        return "checkmark.seal.fill"
    }

    var preflightSummary: String {
        if blockingExportRiskCount > 0 {
            return "\(blockingExportRiskCount) items require attention"
        }
        if pptxReviewRiskCount > 0 {
            return "\(pptxReviewRiskCount) items require review after export"
        }
        if (visualChangeCount ?? 0) > 0 {
            return "\(visualChangeCount ?? 0) visual changes require review"
        }
        return "HTML, PDF, and PPTX are ready for export review"
    }

    var preflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if pptxReviewRiskCount > 0 { return "checklist" }
        if (visualChangeCount ?? 0) > 0 { return "rectangle.2.swap" }
        return "checkmark.seal.fill"
    }

    var blockingExportRiskCount: Int {
        var count = 0
        count += brokenImages
        count += brokenMedia
        if !cleanExport { count += 1 }
        count += textOverflowCount ?? 0
        count += outOfBoundsCount ?? 0
        count += clippedGeometryCount ?? 0
        count += overlayBlockerCount ?? 0
        return count
    }

    var pptxReviewRiskCount: Int {
        var count = 0
        if tableCount > 0 { count += 1 }
        if spanTableCount > 0 { count += 1 }
        if svgCount > 0 { count += 1 }
        if (pptxEffectRiskCount ?? 0) > 0 { count += 1 }
        if (overlapCount ?? 0) > 0 { count += 1 }
        if runtimeCompatibilityRiskCount > 0 { count += 1 }
        return count
    }

    var runtimeCompatibilityRiskCount: Int {
        runtimeRiskCount ?? 0
    }

    var pptxNativeObjectCount: Int {
        (pptxTextObjectCount ?? 0) + (pptxImageObjectCount ?? 0) + (pptxShapeObjectCount ?? 0)
    }

    var pptxMappingTotalObjectCount: Int {
        pptxNativeObjectCount + (pptxReviewObjectCount ?? 0) + (pptxFallbackObjectCount ?? 0)
    }

    var pptxEditableEstimate: Int {
        let total = pptxMappingTotalObjectCount
        guard total > 0 else { return 100 }
        return boundedScore(Int((Double(pptxNativeObjectCount) / Double(total) * 100).rounded()))
    }

    var pptxMappingRecommendation: String {
        if (pptxFallbackObjectCount ?? 0) > 0 {
            return "Some objects must remain whole or have a high risk. For an editable PPTX, convert to an editable version first. For exact visual output, export a PDF."
        }
        if (pptxReviewObjectCount ?? 0) > 0 {
            return "Most objects can be exported as editable content. Review tables, vectors, complex effects, and layered objects after export."
        }
        return "The page contains mostly text, images, and simple shapes. It is suitable for editable PPTX export. Review text boxes and images after export."
    }

    var hasPPTXRepairActions: Bool {
        tableCount > 0
            || svgCount > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || (overlapCount ?? 0) > 0
            || shouldOfferEditableConversion
            || shouldOfferPDFFallback
    }

    var shouldOfferEditableConversion: Bool {
        (pptxFallbackObjectCount ?? 0) > 0 || runtimeCompatibilityRiskCount > 0
    }

    var shouldOfferPDFFallback: Bool {
        (pptxFallbackObjectCount ?? 0) > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || pptxEditabilityScore < 65
    }

    var pptxTextTargetIds: [String] {
        normalizedTargetIds(pptxTextElementIds, fallback: pptxTextElementId)
    }

    var pptxImageTargetIds: [String] {
        normalizedTargetIds(pptxImageElementIds, fallback: pptxImageElementId)
    }

    var pptxShapeTargetIds: [String] {
        normalizedTargetIds(pptxShapeElementIds, fallback: pptxShapeElementId)
    }

    var pptxReviewTargetIds: [String] {
        normalizedTargetIds(pptxReviewElementIds, fallback: pptxReviewElementId)
    }

    var pptxFallbackTargetIds: [String] {
        normalizedTargetIds(pptxFallbackElementIds, fallback: pptxFallbackElementId)
    }

    var visualChangePreviewCanvasWidth: Int {
        if let visualChangeCanvasWidth, visualChangeCanvasWidth > 0 {
            return visualChangeCanvasWidth
        }
        return max(visualChangePreviewItems.map { $0.x + $0.w }.max() ?? 1, 1)
    }

    var visualChangePreviewCanvasHeight: Int {
        if let visualChangeCanvasHeight, visualChangeCanvasHeight > 0 {
            return visualChangeCanvasHeight
        }
        return max(visualChangePreviewItems.map { $0.y + $0.h }.max() ?? 1, 1)
    }

    var runtimeCompatibilityDetail: String {
        let risks = runtimeCompatibilityRiskCount
        if risks == 0 {
            return "Standard HTML objects can be edited directly"
        }

        var parts: [String] = []
        if (scriptCount ?? 0) > 0 || (runtimeRootCount ?? 0) > 0 {
            parts.append("script-rendered content")
        }
        if (iframeCount ?? 0) > 0 {
            parts.append("\(iframeCount ?? 0) embedded pages")
        }
        if (canvasCount ?? 0) > 0 {
            parts.append("\(canvasCount ?? 0) canvases")
        }
        if (shadowRootCount ?? 0) > 0 {
            parts.append("\(shadowRootCount ?? 0) encapsulated components")
        }
        if (overlayBlockerCount ?? 0) > 0 {
            parts.append("\(overlayBlockerCount ?? 0) overlays")
        }
        if (externalResourceCount ?? 0) > 0 {
            parts.append("\(externalResourceCount ?? 0) external resources")
        }
        return parts.isEmpty ? "\(risks) dynamic-content risks" : parts.joined(separator: ", ")
    }

    var responsiveReviewDetail: String {
        let responsiveRules = responsiveRuleCount ?? 0
        let responsiveRisks = responsiveLayoutRiskCount ?? 0
        let responsiveChanges = responsiveChangeCount ?? 0
        let widthSuffix = responsiveReviewWidthText.isEmpty ? "narrow and wide screens" : responsiveReviewWidthText
        if responsiveChanges > 0 {
            return "\(responsiveChanges) changed objects are affected by responsive, flex, grid, or sticky layout rules. Check \(widthSuffix) before export."
        }
        if responsiveRisks == 0 {
            return "No clear responsive rules were detected. A standard width review is sufficient."
        }
        if responsiveRules > 0 {
            return "\(responsiveRules) responsive or container rules were detected. Check \(widthSuffix) after editing."
        }
        return "\(responsiveRisks) flex, grid, or sticky layout objects were detected. Preview multiple widths after editing."
    }

    var responsiveReviewWidthText: String {
        let widths = (responsiveReviewWidths ?? []).filter { $0 > 0 }.prefix(4)
        guard !widths.isEmpty else { return "" }
        return "widths near breakpoints: \(widths.map { "\($0)" }.joined(separator: " / "))px"
    }

    var sourcePollutionReviewCount: Int {
        max(0, inlineStyleChangeCount ?? 0)
            + max(0, externalStylesheetAffectedChangeCount ?? 0)
            + max(0, stylesheetRuleWritebackCount ?? 0)
    }

    var sourcePollutionReviewDetail: String {
        let inlineChanges = inlineStyleChangeCount ?? 0
        let ruleWrites = stylesheetRuleWritebackCount ?? 0
        let stylesheets = stylesheetCount ?? 0
        let externalSheets = externalStylesheetCount ?? 0
        let externalAffectedChanges = externalStylesheetAffectedChangeCount ?? 0
        let ruleTargets = stylesheetRuleWritebackTargets.prefix(3).joined(separator: ", ")
        let ruleTargetSuffix = ruleTargets.isEmpty ? "" : " (\(ruleTargets))"
        if ruleWrites > 0 && inlineChanges == 0 {
            return "\(ruleWrites) style changes were written to local CSS rules\(ruleTargetSuffix). The source remains easier to maintain."
        }
        if ruleWrites > 0 && inlineChanges > 0 {
            return "\(ruleWrites) changes were written to CSS rules\(ruleTargetSuffix), and \(inlineChanges) objects still use inline styles."
        }
        if inlineChanges > 0 && stylesheets > 0 {
            return "\(inlineChanges) changes use inline styles. The source contains \(stylesheets) stylesheets. Review the source before saving."
        }
        if externalAffectedChanges > 0 {
            return "\(externalAffectedChanges) changed objects can be affected by \(externalSheets) external stylesheets. Review widths and class effects before saving."
        }
        if inlineChanges > 0 {
            return "\(inlineChanges) objects use inline-style writeback."
        }
        return "No clear source-contamination risk was detected."
    }

    var htmlReadinessScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 18
            - (cleanExport ? 0 : 30)
            - (textOverflowCount ?? 0) * 10
            - (outOfBoundsCount ?? 0) * 10
            - (clippedGeometryCount ?? 0) * 12
            - min(8, precisionEditingRiskCount)
            - min(12, (overlayBlockerCount ?? 0) * 6)
            - min(8, (responsiveLayoutRiskCount ?? 0) * 2)
            - min(18, (overlapCount ?? 0) * 3)
        )
    }

    var pdfFidelityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 22
            - (textOverflowCount ?? 0) * 12
            - (outOfBoundsCount ?? 0) * 12
            - (clippedGeometryCount ?? 0) * 14
            - min(10, (overlayBlockerCount ?? 0) * 5)
            - min(20, (overlapCount ?? 0) * 4)
        )
    }

    var pptxEditabilityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 16
            - (textOverflowCount ?? 0) * 8
            - (outOfBoundsCount ?? 0) * 8
            - (clippedGeometryCount ?? 0) * 10
            - min(18, (overlapCount ?? 0) * 5)
            - min(16, tableCount * 4)
            - (spanTableCount > 0 ? 18 : 0)
            - min(20, svgCount * 6)
            - min(22, (pptxEffectRiskCount ?? 0) * 4)
            - min(28, runtimeCompatibilityRiskCount * 4)
        )
    }

    var overallExportScore: Int {
        min(htmlReadinessScore, pdfFidelityScore, pptxEditabilityScore)
    }

    var pptxRiskSummary: String {
        if pptxEditabilityScore >= 85 {
            return "PPTX editability is good. Review text boxes and images after export."
        }
        if pptxEditabilityScore >= 65 {
            return "PPTX editability is moderate. Review tables, SVG content, complex effects, dynamic components, and layers after export."
        }
        return "PPTX editability has a high risk. Resolve red issues first. Then review complex effects, script-rendered content, embedded pages, and whole objects."
    }

    private func boundedScore(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private func normalizedTargetIds(_ values: [String]?, fallback: String?) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for value in values ?? [] {
            guard !value.isEmpty, seen.insert(value).inserted else { continue }
            ids.append(value)
        }
        if let fallback, !fallback.isEmpty, seen.insert(fallback).inserted {
            ids.append(fallback)
        }
        return ids
    }
}
