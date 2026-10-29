#!/bin/bash
# Builds B11 Departures and installs it to ~/Applications so the widget shows up in Edit Widgets.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="B11 Departures.app"
BUILT_APP="build/Build/Products/Release/$APP_NAME"
INSTALLED_APP="$HOME/Applications/$APP_NAME"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "Building…"
# A fresh build number each time makes macOS drop its cached copy of the widget.
xcodebuild -project B11Widget.xcodeproj -scheme B11Departures -configuration Release \
    -derivedDataPath build CODE_SIGN_IDENTITY=- CURRENT_PROJECT_VERSION="$(date +%s)" \
    -quiet build

# Only the installed copy should be registered, otherwise macOS may load the one in build/.
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true

echo "Installing to $INSTALLED_APP…"
osascript -e 'quit app "B11 Departures"' 2>/dev/null || true
pkill -f B11WidgetExtension 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"
"$LSREGISTER" -f "$INSTALLED_APP"

# Restart the widget service so it picks up the new version.
killall chronod 2>/dev/null || true
open "$INSTALLED_APP"

echo "Done. Right-click the desktop → Edit Widgets… and add \"B11 from Lysaker brygge\"."
