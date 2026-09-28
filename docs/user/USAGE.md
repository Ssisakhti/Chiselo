# Usage Guide

## Open HTML

Use the Open button or drag a `.html`, `.htm`, or `.xhtml` file into the Chiselo window. You can also drag a file onto `Chiselo.app` in Finder.

Each document opens in a browser-style tab.

## Ordinary And Advanced Modes

Chiselo starts in `Standard` mode. This is the intended light-Dreamweaver workflow: select the rendered object, then edit its content, appearance, or position. DOM structure, source controls, layer tools, dynamic runtime controls, and PPTX-specific options stay hidden.

Switch to `Advanced` when you need the object tree, HTML/CSS source writeback, layer ordering, trusted dynamic-page execution, background controls, editable HTML, or PPTX export. Switching modes does not modify the document.

## Responsive Preview

Use the four viewport buttons in the toolbar to choose the page's original width, desktop (`1440px`), tablet (`768px`), or phone (`390px`). These are real iframe viewport widths, so CSS media and container behavior can reflow. Preview changes do not enter undo history and are never written into HTML.

Check all three device sizes after changing a responsive page, especially around navigation, grids, tables, fixed elements, and long text.

## Static Safety And Dynamic Compatibility

HTML opens in `Static Safe` mode by default. The page's scripts and forms cannot run, while its rendered static HTML, CSS, images, and fonts remain available for editing.

In `Advanced` mode, `Dynamic Compatibility` can be enabled for a trusted file that needs JavaScript to construct its page. Chiselo asks for confirmation first. Do not enable it for unknown HTML: dynamic compatibility intentionally grants the page script and form capabilities inside its editing iframe.

## Select And Edit

- Click rendered HTML content to select an element.
- Double-click text-like elements to edit text in place.
- Use the left object structure only when nested objects are hard to click. Chiselo labels common HTML parts as page, title, image, table, card, module, and cell so you can work from the rendered document instead of reading underlying tags.
- Use Shift/Cmd-click for multi-select.
- Press arrow keys to nudge selected objects.
- Hold Shift with arrow keys for larger nudges.
- Use Command + mouse wheel to zoom.

## Layout Modes

`Free` mode writes fixed positioning and gives HTML a direct visual layout editing feel.

`Transform` mode writes `transform: translate(...)` and is gentler when preserving the original document flow matters.

Chiselo shows detected page or canvas boundaries with center reference lines and ruler ticks. Dragging or resizing objects can snap to the detected page edges and center lines for more precise page-level adjustment.

For repeated HTML objects, use `Children` or `Similar` in the `Refine` panel to select multiple objects, then use `Same Width`, `Same Height`, `Distribute H`, or `Distribute V` in `Align` to make card, image, metric, and module groups consistent.

When an object is selected, the `Geometry` panel shows its distance to the current page/canvas edges and its center offset. Use `Copy Geometry` to copy position, size, margins, and center offset for before/after review.

## Visual Style

Use the `Style` panel to adjust selected objects without editing CSS. Text objects expose font size, weight, line height, color swatches, exact color values, and left/center/right alignment.

Use `Appearance` for fill, border color, border width, corner radius, and shadow presets. These controls apply to direct HTML selections and to objects created by `Convert to Editable Version`.

When local text, typography, line-height, or padding changes would normally reflow the page, Chiselo preserves the selected object's current frame so sibling modules and later sections stay still. Content that no longer fits is reported as overflow for review instead of silently pushing unrelated objects.

When an image is selected, use `Display Mode` to choose `Crop`, `Fit`, or `Stretch`, then replace the image if needed. Chiselo writes these choices back into the exported HTML instead of keeping them as editor-only state.

## Safe Saving

When opening a real local HTML or Chiselo project file, Chiselo creates a one-time sibling backup named like `filename.chiselo-backup.html` or `filename.chiselo-backup.aislide`. If that backup already exists, Chiselo keeps it instead of replacing it.

When saving over an existing HTML or Chiselo project file, Chiselo first copies the previous version into a sibling `.chiselo-history/` folder with a timestamped filename. Use the `Backup` toolbar button to reveal that folder from the current document.

For HTML linked to local CSS files, Chiselo stages the changed CSS files and HTML before committing any of them. If one commit fails, already-written files are restored automatically. Merely opening, previewing, or saving an untouched HTML document preserves the original HTML bytes exactly.

Closing a modified tab asks whether to save, cancel, or discard it. Quitting with modified documents offers Save All, Cancel, or Don't Save, including when the last window is closed.

Static-safe mode disables page scripts and forms and blocks remote HTTP/HTTPS page resources at the native WebKit layer. Use dynamic compatibility only for HTML you trust; enabling it permits the page's scripts, forms, and remote resources after confirmation.

Use the `Restore` toolbar button to open the version history browser. Select any snapshot to see its timestamp, filename, and file size, then restore that specific version. Chiselo asks for confirmation and saves the current file into `.chiselo-history/` before restoring.

## Images

Select an image and use the replace image action. Chiselo embeds the replacement as a data URL so exported HTML remains portable.

## Tables

Select a table, row, or cell to reveal row/column actions. Chiselo handles simple tables and includes extra protection for merged cells.

## Delivery Check

The left sidebar flags delivery risks such as broken resources, temporary editor markers, complex tables, SVG usage, text overflow, out-of-bounds elements, and obvious overlaps. When a risk points to a real HTML element, click it to select that element on the canvas.

Some HTML pages are script-rendered rather than plain static documents. Chiselo flags these as dynamic-content risks when it sees script-built content, embedded pages, canvas regions, external runtime files, or transparent layers that block selection. If the page is difficult to edit as separate objects, use `Convert to Editable Version` to turn the current rendering into a stable object version before final adjustment.

Use `Export` > `Export Preflight` before final delivery. The preflight panel scores HTML readiness, PDF fidelity, and PPTX editability, then lists the issues that should be fixed before export or reviewed after PPTX export.

Chiselo also shows an object-level visual diff against the file as it looked when opened. It tracks changed text, images, position, size, and key visual styles so you can review what actually changed before delivery. When changes are detected, `Visual Change Review` lets you step through the changed objects with `Previous` / `Next` before exporting.

For PPTX, the preflight panel shows a `PPTX Editable Objects` report. It estimates how many visible objects can remain as editable text, images, and simple shapes, and separates objects that need manual review or may have to stay as whole-object fallbacks. Click a non-zero count to jump to the first matching object before export, then use `Previous` / `Next` in `Step Through` to review matching objects one by one.

When PPTX risks are detected, `Suggested Actions` offers direct next steps such as locating tables, SVG/vector objects, complex visual effects, and layered objects, converting difficult script-rendered content into an editable version, or exporting PDF when visual fidelity matters more than PowerPoint editability.

For PPTX, Chiselo also flags complex visual effects such as background images, radial or repeating gradients, filters, masks, clipping paths, blend modes, and 3D transforms. These effects can still look correct in HTML/PDF, but they need extra review when the goal is an editable PowerPoint file.

## Editable Version

`Convert to Editable Version` converts the current rendered HTML into a fixed-canvas Chiselo tab backed by a deterministic Layout IR. Text becomes editable text objects, images become replaceable image objects, and computed visual boxes become adjustable shapes. Embedded pages, canvas regions, and other content that cannot be safely decomposed are kept as whole-object fallbacks with clear editability notes.

After conversion, the left sidebar and export preflight show an editable-version quality summary with direct-editable object counts, fallback counts, and PPTX editability. Captured cards, sections, tables, and visual modules also keep module membership metadata so related objects can be reviewed together.

When you select an object that belongs to a captured module, use `Select Module` in the Inspector to select the whole module. The module can then be moved, nudged with arrow keys, aligned, snapped, duplicated, deleted, or locked as one unit while its internal text, image, and shape objects remain editable.

With the module selected, use `Same Width`, `Same Height`, `Distribute H`, and `Distribute V` to clean up internal card, metric, button, or image spacing without editing code.

## Export

- HTML: clean edited document with Chiselo temporary attributes removed.
- PDF: high-fidelity visual final output.
- PPTX: best-effort object-editable delivery file.

PPTX preflight highlights merged tables, SVG/vector graphics, object overlap, overflow, and missing resources because those areas most often need manual review in PowerPoint.

PDF is the fidelity fallback when a delivery format cannot represent a CSS effect as editable objects.
