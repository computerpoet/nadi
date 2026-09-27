#!/usr/bin/env bash
# Re-sign and re-install nadi on Nelson's iPhone.
#
# Free Apple ID signing certs expire every 7 days, so this needs to run
# once a week. After the iOS platform support is installed (one-time),
# the whole flow takes ~30 seconds.
#
# Usage:
#   ./Scripts/refresh-on-device.sh           # build, install, launch
#   ./Scripts/refresh-on-device.sh --no-launch
#
# If you ever swap iPhones, update DEVICE_UDID and DEVICECTL_ID below.
# Find them with:  xcrun devicectl list devices

set -euo pipefail

# ---- Config ------------------------------------------------------------------
# Hardware UDID — what xcodebuild expects in -destination
DEVICE_UDID="00008140-0009550E22F0801C"
# CoreDevice identifier — what xcrun devicectl expects in --device
DEVICECTL_ID="9A21925F-B038-58BF-9D65-81398CE8179F"
BUNDLE_ID="daelen.nadi"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${PROJECT_DIR}/build"
APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphoneos/nadi.app"

# ---- Pretty output -----------------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
dim()  { printf '\033[2m%s\033[0m\n' "$*"; }

# ---- Args --------------------------------------------------------------------
LAUNCH=1
for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's|^# \{0,1\}||'
      exit 0 ;;
    *) red "Unknown arg: $arg"; exit 2 ;;
  esac
done

# ---- Pre-flight --------------------------------------------------------------
bold "[1/3] Pre-flight"
if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICECTL_ID"; then
  red "Device $DEVICECTL_ID not paired/visible."
  red "Connect the iPhone, unlock it, and re-run."
  exit 1
fi
dim "  device paired ✓"

# ---- Build -------------------------------------------------------------------
bold "[2/3] Building (signed Debug for device)"
cd "$PROJECT_DIR"
xcodebuild build \
  -project nadi.xcodeproj \
  -scheme nadi \
  -configuration Debug \
  -destination "id=${DEVICE_UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  -quiet

if [[ ! -d "$APP_PATH" ]]; then
  red "Build succeeded but $APP_PATH was not produced."
  exit 1
fi
grn "  built: $APP_PATH"

# ---- Install -----------------------------------------------------------------
bold "[3/3] Installing on device"
xcrun devicectl device install app \
  --device "$DEVICECTL_ID" \
  "$APP_PATH"
grn "  installed."

# ---- Launch (optional) -------------------------------------------------------
if [[ "$LAUNCH" -eq 1 ]]; then
  bold "Launching $BUNDLE_ID"
  xcrun devicectl device process launch \
    --device "$DEVICECTL_ID" \
    "$BUNDLE_ID" || {
      red "Launch failed."
      red "If this is the first install with a new cert, open Settings → General → VPN & Device Management on the iPhone and trust the Apple Development cert, then tap the app icon."
      exit 1
    }
fi

grn "Done. Cert valid for ~7 days."
