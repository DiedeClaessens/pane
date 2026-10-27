#!/bin/bash
# Rebuilds Pane and reinstalls it on the iPad, so the free 7-day signature never runs out.
# launchd runs it every day, see scripts/com.diedeclaessens.pane.reinstall.plist and the README.
set -euo pipefail
cd "$(dirname "$0")/.."

ipad=$(<scripts/ipad-id)
build="$HOME/Library/Caches/Pane"
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
echo "$(date '+%Y-%m-%d %H:%M') reinstalling Pane"

# Xcode keeps using a profile until it expires. Removing Pane's profile two days early makes the build fetch a new one in time.
for profile in "$profiles"/*.mobileprovision; do
  contents=$(security cms -D -i "$profile" 2>/dev/null) || continue
  [[ $(plutil -extract Entitlements.application-identifier raw -o - - <<<"$contents") == *.com.diedeclaessens.pane ]] || continue
  expires=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$(plutil -extract ExpirationDate raw -o - - <<<"$contents")" +%s)
  if (( expires - $(date +%s) < 2 * 86400 )); then
    echo "Profile expires $(date -r "$expires" '+%Y-%m-%d %H:%M'), fetching a new one"
    rm "$profile"
  fi
done

# A generic build doesn't need the iPad nearby. Only the install does.
xcodebuild build -project Pane.xcodeproj -scheme Pane -destination 'generic/platform=iOS' \
  -derivedDataPath "$build" -allowProvisioningUpdates -quiet
xcrun devicectl device install app --device "$ipad" "$build/Build/Products/Debug-iphoneos/Pane.app"
echo "Installed, signature valid until $(security cms -D -i "$build/Build/Products/Debug-iphoneos/Pane.app/embedded.mobileprovision" | plutil -extract ExpirationDate raw -o - -)"
