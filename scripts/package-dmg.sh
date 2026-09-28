#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/outputs"
APP_NAME="Chiselo"
BUNDLE_ID="com.fangle.chiselo"
DEFAULT_VERSION="$(node -p "require(process.argv[1]).version" "$ROOT_DIR/config/release.json")"
DEFAULT_BUILD_NUMBER="$(node -p "require(process.argv[1]).buildNumber" "$ROOT_DIR/config/release.json")"
VERSION="${CHISELO_VERSION:-$DEFAULT_VERSION}"
BUNDLE_VERSION="${CHISELO_BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
BUILD_CONFIG="release"
BUILD_DIR=""
APP_BUNDLE="$ROOT_DIR/.build/package/$APP_NAME.app"
ADHOC_ENTITLEMENTS="$ROOT_DIR/.build/package/$APP_NAME-adhoc-entitlements.plist"
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
RELEASE_PREFIX="${CHISELO_R2_PREFIX:-chiselo}"
DOWNLOAD_BASE_URL="${CHISELO_DOWNLOAD_BASE_URL:-https://downloads.vellumloop.com}"
DOWNLOAD_URL="${CHISELO_DOWNLOAD_URL:-}"
SWIFTPM_SCRATCH_PATH="${CHISELO_SWIFTPM_SCRATCH_PATH:-}"
SPARKLE_PUBLIC_KEY="${CHISELO_SPARKLE_PUBLIC_KEY:-}"
SPARKLE_FRAMEWORK="${CHISELO_SPARKLE_FRAMEWORK:-}"
NOTARIZE_DMG="${CHISELO_NOTARIZE:-0}"
NOTARY_KEY="${CHISELO_NOTARY_KEY:-}"
NOTARY_KEY_ID="${CHISELO_NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${CHISELO_NOTARY_ISSUER:-}"
NOTARY_PROFILE="${CHISELO_NOTARY_PROFILE:-}"
BUILD_FINGERPRINT="${CHISELO_BUILD_FINGERPRINT:-}"
BUILD_TIMESTAMP="${CHISELO_BUILD_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

cd "$ROOT_DIR"

compute_build_fingerprint() {
  if [[ -n "$BUILD_FINGERPRINT" ]]; then
    printf '%s\n' "$BUILD_FINGERPRINT"
    return
  fi

  local head
  head="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -z "$head" ]]; then
    date -u +%Y%m%d%H%M%S
    return
  fi

  if git diff --quiet --ignore-submodules -- && git diff --cached --quiet --ignore-submodules -- && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
    printf '%s\n' "$head"
    return
  fi

  local dirty_hash
  dirty_hash="$(
    {
      git diff --binary --ignore-submodules --
      git diff --cached --binary --ignore-submodules --
      git ls-files --others --exclude-standard | while IFS= read -r path; do
        if [[ "$path" == .build/* || "$path" == outputs/* ]]; then
          continue
        fi
        [[ -f "$path" ]] && shasum -a 256 "$path"
      done
    } | shasum -a 256 | awk '{print substr($1,1,8)}'
  )"
  printf '%s-dirty-%s\n' "$head" "$dirty_hash"
}

BUILD_FINGERPRINT="$(compute_build_fingerprint)"
if [[ -z "$DOWNLOAD_URL" ]]; then
  DOWNLOAD_URL="${DOWNLOAD_BASE_URL%/}/$RELEASE_PREFIX/Chiselo-${VERSION}.dmg?build=$BUILD_FINGERPRINT"
fi

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

if [[ "$NOTARIZE_DMG" == "1" && "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Apple notarization requires a Developer ID signing identity." >&2
  exit 1
fi

sign_app_bundle() {
  local target="$1"
  codesign --force --deep --options runtime "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$target"
}

sign_app_container() {
  local target="$1"
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
      --entitlements "$ADHOC_ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" "$target"
  else
    codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
      --sign "$SIGNING_IDENTITY" "$target"
  fi
}

sign_embedded_bundles() {
  local target="$1"
  local signed_count=0
  local bundle_path
  local search_root="$target"

  if [[ -d "$target/Contents" ]]; then
    search_root="$target/Contents"
  fi

  while IFS= read -r bundle_path; do
    [[ "$bundle_path" == "$target" ]] && continue
    sign_app_bundle "$bundle_path"
    signed_count=$((signed_count + 1))
  done < <(find "$search_root" -type d \( \
    -name '*.framework' -o \
    -name '*.app' -o \
    -name '*.xpc' -o \
    -name '*.appex' \
  \) -prune -print | sort -r)

  echo "==> Signed $signed_count embedded bundle(s)"
}

sign_macho_resources() {
  local target="$1"
  local signed_count=0
  local file_path

  while IFS= read -r -d '' file_path; do
    if file "$file_path" | grep -q "Mach-O"; then
      codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$file_path"
      signed_count=$((signed_count + 1))
    fi
  done < <(find "$target" -type f \
    ! -path '*/_CodeSignature/*' \
    ! -path '*/Contents/MacOS/*' \
    -print0)

  echo "==> Signed $signed_count embedded Mach-O resource(s)"
}

find_sparkle_framework() {
  if [[ -n "$SPARKLE_FRAMEWORK" && -d "$SPARKLE_FRAMEWORK" ]]; then
    printf '%s\n' "$SPARKLE_FRAMEWORK"
    return 0
  fi
  if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR/Sparkle.framework" ]]; then
    printf '%s\n' "$BUILD_DIR/Sparkle.framework"
    return 0
  fi
  if [[ -n "$SWIFTPM_SCRATCH_PATH" ]]; then
    find "$SWIFTPM_SCRATCH_PATH/artifacts/sparkle/Sparkle" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null
    return 0
  fi
  find "$ROOT_DIR/.build/artifacts/sparkle/Sparkle" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null
}

copy_sparkle_framework() {
  local framework
  framework="$(find_sparkle_framework)"
  if [[ -z "$framework" || ! -d "$framework" ]]; then
    echo "Missing Sparkle.framework. Run swift build once, or set CHISELO_SPARKLE_FRAMEWORK." >&2
    exit 1
  fi
  mkdir -p "$APP_BUNDLE/Contents/Frameworks"
  rsync -a --delete "$framework" "$APP_BUNDLE/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
}

swift_build() {
  if [[ -n "$SWIFTPM_SCRATCH_PATH" ]]; then
    swift build -c "$BUILD_CONFIG" --scratch-path "$SWIFTPM_SCRATCH_PATH" "$@"
  else
    swift build -c "$BUILD_CONFIG" "$@"
  fi
}

notarize_dmg() {
  local dmg_path="$1"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$dmg_path" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
    return
  fi

  if [[ -z "$NOTARY_KEY" || -z "$NOTARY_KEY_ID" || -z "$NOTARY_ISSUER" ]]; then
    echo "Apple notarization requires CHISELO_NOTARY_KEY, CHISELO_NOTARY_KEY_ID, and CHISELO_NOTARY_ISSUER, or set CHISELO_NOTARY_PROFILE." >&2
    exit 1
  fi

  if [[ ! -f "$NOTARY_KEY" ]]; then
    echo "Missing Apple notarization key file: $NOTARY_KEY" >&2
    exit 1
  fi

  xcrun notarytool submit "$dmg_path" \
    --key "$NOTARY_KEY" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER" \
    --wait
}

echo "==> Generating design tokens"
node "$ROOT_DIR/scripts/generate-design-tokens.mjs"

echo "==> Building $APP_NAME ($BUILD_CONFIG)"
swift_build
BUILD_DIR="$(swift_build --show-bin-path | tail -n 1)"

if [[ -z "$SPARKLE_PUBLIC_KEY" && -f "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" ]]; then
  SPARKLE_PUBLIC_KEY="$(swift "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" public-key 2>/dev/null || true)"
fi
if [[ -z "$SPARKLE_PUBLIC_KEY" || "$SPARKLE_PUBLIC_KEY" == "REPLACE_WITH_CHISELO_SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "Missing Sparkle public key. Run: swift scripts/chiselo-sparkle-tool.swift ensure-key" >&2
  exit 1
fi
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) PUBLIC_ARCH="arm64" ;;
  x86_64) PUBLIC_ARCH="x86_64" ;;
  *) PUBLIC_ARCH="$ARCH" ;;
esac
SPARKLE_FEED_URL="${CHISELO_SPARKLE_FEED_URL:-${DOWNLOAD_BASE_URL%/}/$RELEASE_PREFIX/latest/appcast-$PUBLIC_ARCH.xml}"

echo "==> Generating app icon"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICON_DIR"

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$DMG_STAGING"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp -R "$BUILD_DIR/Chiselo_Chiselo.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/Chiselo.icns"
copy_sparkle_framework

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
  <string>$BUNDLE_VERSION</string>
  <key>ChiseloBuildFingerprint</key>
  <string>$BUILD_FINGERPRINT</string>
  <key>ChiseloBuildTimestamp</key>
  <string>$BUILD_TIMESTAMP</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
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

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  cat > "$ADHOC_ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
PLIST
fi

echo "==> Signing app ($CODESIGN_LABEL)"
xattr -cr "$APP_BUNDLE"
sign_macho_resources "$APP_BUNDLE"
sign_embedded_bundles "$APP_BUNDLE"
sign_app_container "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

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

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  README_SIGNING_STATUS="$(cat <<'TEXT'
- The app and DMG are signed with a Developer ID certificate.
- Apple notarization is enabled for this package. The script staples the notarization ticket to the DMG.
TEXT
)"
  README_SIGNING_STATUS="$README_SIGNING_STATUS
- Before installation, run xcrun stapler validate Chiselo-${VERSION}.dmg to check the notarization ticket."
  UPDATE_PACKAGE_STATUS="$(cat <<'TEXT'
- The app and DMG are signed with Developer ID.
- Apple notarization and stapling are enabled for this package.
- The app includes Sparkle updates. Update checks use the packaged appcast URL and Ed25519 public key.
TEXT
)"
else
  README_SIGNING_STATUS="$(cat <<'TEXT'
- The app and DMG use the available Developer ID certificate.
- This local packaging run did not perform Apple notarization or stapling.
- If notarization is not completed separately, macOS can show a security message on first launch.
TEXT
)"
  UPDATE_PACKAGE_STATUS="$(cat <<'TEXT'
- The app and DMG are signed with Developer ID.
- This package did not perform Apple notarization or stapling.
- Complete notarization and stapling before a public release to reduce Gatekeeper messages.
- The app includes Sparkle updates. Update checks use the packaged appcast URL and Ed25519 public key.
TEXT
)"
fi

cat > "$DMG_STAGING/README.txt" <<README
Chiselo
==========

Visual HTML editing and delivery

Install
-------
1. Open this DMG.
2. Drag Chiselo.app to the Applications folder.
3. Start Chiselo from Applications. Do not run it directly from the DMG.

Signing Status
--------------
$README_SIGNING_STATUS

If macOS blocks the first launch:

1. Confirm that Chiselo.app is in Applications.
2. In Finder, open Applications. Right-click Chiselo.app and select Open.
3. If System Settings shows Open Anyway, open System Settings -> Privacy & Security and confirm the launch.

Files
-----
- README.txt: installation, signing status, and notes.
- Release Notes.txt: main changes in the current version.

Current Capabilities
--------------------
- Open and edit existing or generated HTML pages and documents.
- Drop HTML, HTM, or XHTML files on the window, tab bar, sidebar, or canvas.
- Use browser-style tabs. Each document keeps an independent editing state.
- Open files from Finder with drag and drop or Open With.
- Check for updates with Sparkle and the signed appcast.
- Edit pages, documents, reports, posters, dashboards, and slide-style HTML.
- Repair HTML fragments that do not include html, head, or body elements.
- Select visible objects directly on the canvas or use the object structure.
- Edit text in place and keep unrelated objects stable.
- Move, resize, align, distribute, snap, and nudge selected objects.
- Replace images and adjust how they fit their frames.
- Add or remove table rows and columns while protecting merged cells.
- Review broken resources, complex tables, SVG content, source cleanliness, and responsive risks.
- Export clean HTML, high-fidelity PDF, and object-level editable PPTX.
- Keep an original .chiselo-backup and create .chiselo-history snapshots before overwriting files.
- Restore a selected history snapshot with atomic replacement and rollback.

Notes
-----
- This is a development preview build.
- Use dynamic compatibility only for trusted HTML that requires scripts or remote resources.
- Make a copy of important HTML before you edit it.
README

cat > "$DMG_STAGING/Release Notes.txt" <<README
Chiselo ${VERSION} Release Notes
===============================

Package Status
--------------
$UPDATE_PACKAGE_STATUS

Changes in This Release
-----------------------
- The version is ${VERSION}, and the Sparkle CFBundleVersion is ${BUNDLE_VERSION}.
- Text editing locks the selected object's local frame and the canvas view while you type.
- Selection geometry, zoom, and unrelated objects remain stable during text entry.
- Ending text editing performs one consolidated layout update.
- Root document elements cannot be selected, edited, moved, duplicated, arranged, or deleted.
- Hierarchy navigation skips hidden, runtime, and non-editable nodes.
- Save, export, and editable conversion remain bound to the tab that started the operation.
- Snapshot restore uses a prepared temporary file, atomic replacement, and rollback.
- Repeated editable HTML export replaces the existing runtime instead of adding duplicate blocks.
- HTML opens at its original 100% CSS-pixel scale.
- Static-safe mode blocks remote pages, images, styles, scripts, fonts, and media.
- HTML and linked local CSS use transactional writeback with automatic rollback.
- The release includes Swift, WebKit, editing-isolation, and runtime-safety tests.

Delivery Features
-----------------
- Keep an original .chiselo-backup and save .chiselo-history snapshots.
- Export clean HTML, high-fidelity PDF, and object-level editable PPTX.
- Use Sparkle update checks with signed update metadata.
- Online verification checks the version, build number, feed URL, Ed25519 signature, file length, and SHA-256.
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

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  echo "==> Notarizing DMG with Apple notary service"
  notarize_dmg "$DMG_PATH"
  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  echo "==> Re-verifying stapled DMG"
  hdiutil verify "$DMG_PATH"
fi

APPCAST_PATH="$OUTPUT_DIR/Chiselo-${VERSION}-macOS-${PUBLIC_ARCH}-appcast.xml"
APPCAST_LATEST_DIR="$OUTPUT_DIR/latest"
APPCAST_LATEST_PATH="$APPCAST_LATEST_DIR/appcast-$PUBLIC_ARCH.xml"
echo "==> Writing Sparkle appcast"
mkdir -p "$APPCAST_LATEST_DIR"
swift "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" write-appcast \
  --output "$APPCAST_PATH" \
  --archive "$DMG_PATH" \
  --download-url "$DOWNLOAD_URL" \
  --short-version "$VERSION" \
  --bundle-version "$BUNDLE_VERSION" \
  --minimum-system-version "13.0" \
  --arch "$PUBLIC_ARCH" \
  --expected-public-key "$SPARKLE_PUBLIC_KEY" \
  --app-name "$APP_NAME" \
  --link "${CHISELO_PRODUCT_URL:-https://downloads.vellumloop.com/chiselo}"
cp "$APPCAST_PATH" "$APPCAST_LATEST_PATH"

echo "Created: $OUTPUT_APP_BUNDLE"
if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "Synced: $DEFAULT_OUTPUT_APP_BUNDLE"
fi
echo "Created: $DMG_PATH"
echo "Created: $APPCAST_PATH"
echo "Created: $APPCAST_LATEST_PATH"
