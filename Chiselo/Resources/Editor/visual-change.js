(() => {
  "use strict";

  function create(dependencies = {}) {
    const {
      visualStylesheetRuleDiffers,
      truncateDiagnosticText,
      maxRevertTextLength = 10000
    } = dependencies;

    if (typeof visualStylesheetRuleDiffers !== "function") {
      throw new TypeError("ChiseloVisualChange requires visualStylesheetRuleDiffers().");
    }
    if (typeof truncateDiagnosticText !== "function") {
      throw new TypeError("ChiseloVisualChange requires truncateDiagnosticText().");
    }

    function filterVisualChangeRecords(records) {
      return records.filter((record) => !isDuplicateAncestorVisualChange(record, records));
    }

    function isDuplicateAncestorVisualChange(record, records) {
      if (!record?.key || record.kind !== "文字") return false;
      const childPrefix = `${record.key} > `;
      return records.some((other) => (
        other !== record
        && other.kind === "文字"
        && typeof other.key === "string"
        && other.key.startsWith(childPrefix)
      ));
    }

    function visualChangePreviewItem({ key, kind, before, after, revertInfo }) {
      const entry = after || before || {};
      const rect = entry?.rect || {};
      const detail = visualChangeDetail(kind, before, after);
      const writebackKind = visualChangeWritebackKind(before, after);
      const writebackTarget = visualChangeWritebackTarget(writebackKind, before, after);
      return {
        changeKey: key || null,
        elementId: entry?.elementId || null,
        label: truncateDiagnosticText(entry?.label || "", "Object"),
        kind,
        detail: detail.detail,
        beforeValue: detail.beforeValue,
        afterValue: detail.afterValue,
        writebackKind,
        writebackLabel: visualChangeWritebackLabel(writebackKind),
        writebackTarget,
        canRevert: Boolean(revertInfo?.canRevert),
        revertReason: revertInfo?.reason || null,
        x: Math.round(Number(rect.x || 0)),
        y: Math.round(Number(rect.y || 0)),
        w: Math.round(Number(rect.w || 0)),
        h: Math.round(Number(rect.h || 0))
      };
    }

    function visualChangeWritebackKind(before, after) {
      if (!before || !after) return null;
      if (visualChangeIsLocalFrameStabilityOnly(before, after)) return "layout-stability";
      if (String(before.styleAttr || "") !== String(after.styleAttr || "")) return "inline-style";
      if (visualStylesheetRuleDiffers(before, after)) return "stylesheet-rule";
      return null;
    }

    function visualChangeIsLocalFrameStabilityOnly(before, after) {
      if (!before || !after || before.localFrameLocked || !after.localFrameLocked) return false;
      const hasWriteback = String(before.styleAttr || "") !== String(after.styleAttr || "")
        || visualStylesheetRuleDiffers(before, after);
      return hasWriteback
        && visualStyleDiffKeys(before.style, after.style).length === 0
        && !rectDiffers(before.rect, after.rect);
    }

    function visualChangeWritebackTarget(kind, before, after) {
      if (kind === "inline-style") return "style";
      if (kind === "stylesheet-rule") return after?.stylesheetRule?.selector || before?.stylesheetRule?.selector || null;
      if (kind === "layout-stability") {
        return visualStylesheetRuleDiffers(before, after)
          ? after?.stylesheetRule?.selector || before?.stylesheetRule?.selector || null
          : "style";
      }
      return null;
    }

    function visualChangeWritebackLabel(kind) {
      if (kind === "inline-style") return "inline style";
      if (kind === "stylesheet-rule") return "CSS rule";
      if (kind === "layout-stability") return "Local frame protection";
      return null;
    }

    function visualChangeRevertInfo(kind, before, after) {
      if (!before && after) {
        return { canRevert: true, reason: null };
      }
      if (before && !after) {
        return before.outerHTML && before.parentKey
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "The deleted object has no restorable source snapshot. Restore it from version history or rebuild it manually." };
      }
      if (!before || !after) {
        return { canRevert: false, reason: "The opening or current object snapshot is missing." };
      }

      if (kind === "文字") {
        if (before.childElementCount > 0 || after.childElementCount > 0) {
          return { canRevert: false, reason: "The object contains inline structure. Automatic revert can damage the source hierarchy." };
        }
        if (String(before.text || "").length > maxRevertTextLength) {
          return { canRevert: false, reason: "The text is too long. Locate the object and review it manually." };
        }
        return { canRevert: true, reason: null };
      }

      if (kind === "图片") {
        return after.imageSource !== undefined
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "The current object is not a replaceable image." };
      }

      if (kind === "位置/尺寸" || kind === "样式") {
        return before.styleAttr !== after.styleAttr || visualStylesheetRuleDiffers(before, after)
          ? { canRevert: true, reason: null }
          : { canRevert: false, reason: "The change comes from a stylesheet, responsive rule, or parent layout. Locate the object and review it manually." };
      }

      return { canRevert: false, reason: "One-click revert is not available for this type of change." };
    }

    function visualChangeDetail(kind, before, after) {
      if (!before && after) {
        return {
          detail: "This object was added. Revert removes it from the current HTML.",
          beforeValue: "None",
          afterValue: visualRectText(after.rect)
        };
      }
      if (before && !after) {
        return {
          detail: "This object was deleted. One-click revert can restore it to its opening position.",
          beforeValue: visualRectText(before.rect),
          afterValue: "Deleted"
        };
      }
      if (!before || !after) {
        return { detail: "A comparable snapshot is missing.", beforeValue: null, afterValue: null };
      }

      if (kind === "位置/尺寸") {
        return {
          detail: "The position or size changed.",
          beforeValue: visualRectText(before.rect),
          afterValue: visualRectText(after.rect)
        };
      }
      if (kind === "文字") {
        return {
          detail: "The text content changed.",
          beforeValue: truncateDiagnosticText(before.text, "Empty text"),
          afterValue: truncateDiagnosticText(after.text, "Empty text")
        };
      }
      if (kind === "图片") {
        return {
          detail: "The image source changed.",
          beforeValue: visualSourceLabel(before.imageSource),
          afterValue: visualSourceLabel(after.imageSource)
        };
      }

      const changedStyles = visualStyleDiffKeys(before.style, after.style);
      const detailSuffix = visualStylesheetRuleDiffers(before, after) ? " (written back to a stylesheet rule)" : "";
      return {
        detail: changedStyles.length ? `Key style changes: ${changedStyles.join(", ")}${detailSuffix}` : `Key styles changed${detailSuffix}.`,
        beforeValue: visualStyleSummary(before.style, changedStyles),
        afterValue: visualStyleSummary(after.style, changedStyles)
      };
    }

    function visualRectText(rect) {
      if (!rect) return "";
      return `x ${Math.round(rect.x || 0)}, y ${Math.round(rect.y || 0)}, ${Math.round(rect.w || 0)} x ${Math.round(rect.h || 0)}`;
    }

    function visualSourceLabel(value) {
      const source = String(value || "").trim();
      if (!source) return "Empty";
      if (source.startsWith("data:")) return "Embedded image";
      return truncateDiagnosticText(source.split(/[/?#]/).filter(Boolean).pop() || source, source);
    }

    function visualStyleDiffKeys(before = {}, after = {}) {
      const labels = {
        color: "Text color",
        background: "Background",
        borderColor: "Border color",
        borderWidth: "Border",
        radius: "Corner radius",
        fontSize: "Font size",
        fontWeight: "Font weight",
        textAlign: "Alignment",
        objectFit: "Image fit",
        opacity: "Opacity",
        shadow: "Shadow"
      };
      return Object.keys(labels).filter((key) => JSON.stringify(before?.[key]) !== JSON.stringify(after?.[key])).map((key) => labels[key]);
    }

    function visualStyleSummary(style = {}, changedKeys = []) {
      if (!changedKeys.length) return "";
      const reverseLabels = {
        "Text color": "color",
        "Background": "background",
        "Border color": "borderColor",
        "Border": "borderWidth",
        "Corner radius": "radius",
        "Font size": "fontSize",
        "Font weight": "fontWeight",
        "Alignment": "textAlign",
        "Image fit": "objectFit",
        "Opacity": "opacity",
        "Shadow": "shadow"
      };
      return changedKeys
        .slice(0, 3)
        .map((label) => `${label} ${truncateDiagnosticText(style?.[reverseLabels[label]], "Empty")}`)
        .join("; ");
    }

    function visualEntryChangeKind(before, after) {
      if (before.imageSource !== after.imageSource) return "图片";
      if (before.text !== after.text && !(before.childElementCount > 0 || after.childElementCount > 0)) return "文字";
      if (JSON.stringify(before.style) !== JSON.stringify(after.style)) return "样式";
      if (rectDiffers(before.rect, after.rect)) return "位置/尺寸";
      return null;
    }

    function rectDiffers(before, after) {
      if (!before || !after) return true;
      return Math.abs(before.x - after.x) > 2
        || Math.abs(before.y - after.y) > 2
        || Math.abs(before.w - after.w) > 2
        || Math.abs(before.h - after.h) > 2;
    }

    return Object.freeze({
      filterRecords: filterVisualChangeRecords,
      previewItem: visualChangePreviewItem,
      writebackKind: visualChangeWritebackKind,
      isLocalFrameStabilityOnly: visualChangeIsLocalFrameStabilityOnly,
      revertInfo: visualChangeRevertInfo,
      entryChangeKind: visualEntryChangeKind
    });
  }

  window.ChiseloVisualChange = Object.freeze({ create });
})();
