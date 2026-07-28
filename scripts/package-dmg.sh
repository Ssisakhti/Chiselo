#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/outputs"
APP_NAME="Chiselo"
BUNDLE_ID="com.fangle.chiselo"
VERSION="0.1.11"
BUILD_CONFIG="release"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG"
APP_BUNDLE="$ROOT_DIR/.build/package/$APP_NAME.app"
DMG_STAGING="$ROOT_DIR/.build/dmg-staging"
OUTPUT_APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
DEFAULT_OUTPUT_APP_BUNDLE="$DEFAULT_OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg"
ICON_DIR="$ROOT_DIR/Chiselo/Resources/AppIcon"
ICON_FILE="$ICON_DIR/Chiselo.icns"
TEAM_ID="JF8T4Y5B5R"
TEAM_NAME="Wuhan Fan Ge Network Technology Co., Ltd."
DEFAULT_DEVELOPER_ID="Developer ID Application: ${TEAM_NAME} (${TEAM_ID})"
SIGNING_IDENTITY="${CODESIGN_IDENTITY:-${SIGN_IDENTITY:-}}"

cd "$ROOT_DIR"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$DEFAULT_DEVELOPER_ID\"" >/dev/null; then
    SIGNING_IDENTITY="$DEFAULT_DEVELOPER_ID"
  else
    SIGNING_IDENTITY="-"
  fi
fi

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  CODESIGN_TIMESTAMP=(--timestamp=none)
  CODESIGN_LABEL="ad-hoc"
else
  CODESIGN_TIMESTAMP=(--timestamp)
  CODESIGN_LABEL="$SIGNING_IDENTITY"
fi

sign_app_bundle() {
  local target="$1"
  codesign --force --deep --options runtime "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$target"
}

echo "==> Generating design tokens"
node "$ROOT_DIR/scripts/generate-design-tokens.mjs"

echo "==> Building $APP_NAME ($BUILD_CONFIG)"
swift build -c "$BUILD_CONFIG"

echo "==> Generating app icon"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICON_DIR"

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$DMG_STAGING"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp -R "$BUILD_DIR/Chiselo_Chiselo.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/Chiselo.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>Chiselo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>HTML Document</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.html</string>
        <string>public.xhtml</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Chiselo Project</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.json</string>
        <string>app.chiselo.aislide</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>app.chiselo.aislide</string>
      <key>UTTypeDescription</key>
      <string>Chiselo Project</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.json</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>aislide</string>
        </array>
      </dict>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Signing app ($CODESIGN_LABEL)"
sign_app_bundle "$APP_BUNDLE"

echo "==> Preparing DMG staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Copying direct app bundle"
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_APP_BUNDLE"
cp -R "$APP_BUNDLE" "$OUTPUT_APP_BUNDLE"

if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "==> Syncing default local app bundle"
  mkdir -p "$DEFAULT_OUTPUT_DIR"
  rm -rf "$DEFAULT_OUTPUT_APP_BUNDLE"
  cp -R "$APP_BUNDLE" "$DEFAULT_OUTPUT_APP_BUNDLE"
fi

cat > "$DMG_STAGING/README.txt" <<'README'
Chiselo
==========

Chisel your HTML

Install
-------
1. Open this DMG.
2. Drag Chiselo.app into the Applications folder.
3. Launch Chiselo from Applications.

First Launch
------------
This is a locally packaged, un-notarized build. If macOS blocks the first
launch, read this file in the same folder:

- First Launch Help.txt

The most common fixes:

1. Drag Chiselo.app into Applications first, then open it.
2. Right-click Chiselo.app in Finder, choose Open, then confirm once more.
3. If System Settings offers "Open Anyway", click it.

Current Capabilities
--------------------
- Positioning: an HTML refinement and delivery tool.
- Open and refine existing or generated HTML pages and documents.
- Drag external HTML / HTM / XHTML files straight into the window to open them.
- Drop files onto the window, the tab bar, the sidebar, or the center canvas;
  the canvas no longer swallows HTML file drops.
- Browser-style tabs: each HTML file or Chiselo project keeps its own editing
  snapshot, and tabs can be switched and closed.
- Drag an HTML file from Finder onto the Chiselo.app icon, or use Open With to
  go straight into editing.
- A macOS-native Chiselo icon is built in and appears in Finder, the Dock, the
  installer, and the app switcher.
- Supports pages, documents, reports, posters, dashboards, and slide-style HTML.
- Automatically repairs fragment HTML or HTML missing its html/head/body wrapper.
- macOS frosted-glass interface: a light sidebar, a clean canvas backdrop, and
  unified design tokens.
- Select content by clicking the canvas or the Object Structure panel.
- Click objects directly in the canvas body; Object Structure is a helper for
  picking a precise level.
- Double-click headings, paragraphs, list items, table cells, and other text
  nodes to edit in place; pressing Enter on a selected text node also works.
- Hold Command and scroll to zoom the canvas; handles stay large enough to grab.
- In-canvas hover hints and a selection quick-action bar for editing text,
  replacing images, duplicating, deleting, and moving objects front or back.
- Shift/Cmd-click to select multiple page objects, with support for selecting
  similar objects, child objects, and adjusting groups.
- Drag, resize, align, fill, snap to grid, and nudge.
- Edit text, replace images, detect broken images, add and remove table rows and
  columns, and adjust cell styles.
- The Delivery Check panel on the left flags broken resources, complex tables,
  SVG, and clean-HTML status.
- Table row and column operations protect rowspan / colspan merged cells.
- A companion automated visual QA script screenshots each page to check for
  out-of-bounds objects, occlusion, and text overflow.
- Export clean HTML, high-fidelity PDF, and object-level editable PPTX; the
  output formats serve final delivery.
- Opening a real HTML or Chiselo project file keeps a .chiselo-backup of the
  original, prompts you to confirm the backup before the first edit, and writes
  a .chiselo-history version snapshot before overwriting on save.
- The toolbar can open the backup folder and, after confirmation, restore the
  most recent snapshot.

Notes
-----
- This is a development preview build.
- Deep editing of complex script-driven pages, cross-origin resources,
  animations, and pseudo-elements is still being iterated on.
- If you are only trying it out, copy your HTML file before opening it to edit.
README

cat > "$DMG_STAGING/First Launch Help.txt" <<'README'
Chiselo First Launch Help
=========================

The first time you install Chiselo, macOS may say:

- "unidentified developer" / "cannot verify the developer"
- "is damaged and should be moved to the Trash"
- "cannot be opened because Apple cannot check it for malicious software"

This usually does not mean the file is broken. It means this preview build has
not gone through Apple notarization.

Try these in order:

Option 1: Right-click to open
-----------------------------
1. Drag Chiselo.app into Applications first.
2. Open Finder -> Applications.
3. Find Chiselo.app.
4. Right-click it and choose Open.
5. When macOS asks again, click Open once more.

This is the simplest and recommended approach.

Option 2: Click "Open Anyway" in System Settings
------------------------------------------------
1. Double-click Chiselo.app once.
2. After the block message appears, open:
   System Settings -> Privacy & Security
3. Scroll down to the Security section.
4. If you see Chiselo was blocked, click "Open Anyway".
5. Confirm the launch once more.

Option 3: If macOS says "damaged" or "move to Trash"
----------------------------------------------------
Some macOS versions describe an un-notarized app as damaged. If you are sure you
downloaded this app from the GitHub Release, run this in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Chiselo.app
```

Then go back to Applications and double-click or right-click to open it.

Option 4: Run from source
-------------------------
If you are comfortable with the command line, you can launch from source:

```bash
swift run Chiselo
```

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Swift 5.9 or later

Additional Notes
----------------
- Prefer downloading the official DMG from the GitHub Release.
- On first launch, drag the app into Applications rather than running it from
  inside the DMG.
- If it still will not open, download the DMG again and retry.
README

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  echo "==> Signing DMG ($CODESIGN_LABEL)"
  codesign --force "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH"

echo "Created: $OUTPUT_APP_BUNDLE"
if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "Synced: $DEFAULT_OUTPUT_APP_BUNDLE"
fi
echo "Created: $DMG_PATH"
