#!/bin/bash
set -euo pipefail

repo_root="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${IOS_DESTINATION:?Set IOS_DESTINATION to an iOS simulator UUID}"
if [[ ! "$IOS_DESTINATION" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
  printf 'IOS_DESTINATION must be an iOS simulator UUID.\n' >&2
  exit 2
fi
if [[ ! -x "$repo_root/e2e/node_modules/.bin/e2e" ]]; then
  printf 'Install the pilot dependencies with npm --prefix e2e ci.\n' >&2
  exit 2
fi

derived_data="$repo_root/.build/e2e-ios"
xcodebuild -project "$repo_root/MojeZegarki.xcodeproj" -scheme MojeZegarki \
  -configuration Debug -destination "platform=iOS Simulator,id=$IOS_DESTINATION" \
  -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO \
  PRODUCT_BUNDLE_IDENTIFIER=pl.jakubbatycki.MojeZegarki.E2EPilot build
xcrun simctl bootstatus "$IOS_DESTINATION" -b
xcrun simctl install "$IOS_DESTINATION" "$derived_data/Build/Products/Debug-iphonesimulator/MojeZegarki.app"

cd "$repo_root/e2e"
export IOS_DESTINATION E2E_TELEMETRY_DISABLED=1
export AGENT_DEVICE_STATE_DIR="$repo_root/.build/e2e-driver"
mkdir -m 700 -p "$AGENT_DEVICE_STATE_DIR"
exec ./node_modules/.bin/e2e run --target ios "$@"
