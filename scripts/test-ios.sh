#!/bin/bash
set -euo pipefail
script_path="$(realpath -- "${BASH_SOURCE[0]}")"
repo_root="$(CDPATH= cd "$(dirname "$script_path")/.." && pwd)"
# Supply a simulator UUID from simctl, or an explicit simulator destination.
: "${IOS_DESTINATION:?Set IOS_DESTINATION to a simulator UUID or a platform=iOS Simulator destination}"
destination="$IOS_DESTINATION"
if [[ "$destination" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
  destination="platform=iOS Simulator,id=$destination"
elif [[ "$destination" != 'platform=iOS Simulator,'* ]]; then
  printf 'IOS_DESTINATION must identify an iOS simulator. Run device tests in Xcode with signing configured.\n' >&2
  exit 2
fi

result_path="${RESULT_PATH:-}"
if [[ -z "$result_path" ]]; then
  results_root="$repo_root/.build/TestResults"
  mkdir -p "$results_root"
  run_directory="$(mktemp -d "$results_root/Regression.XXXXXX")"
  result_path="$run_directory/Regression.xcresult"
else
  mkdir -p "$(dirname "$result_path")"
fi
printf 'Test result bundle: %s\n' "$result_path"
exec xcodebuild -project "$repo_root/MojeZegarki.xcodeproj" -scheme MojeZegarki -testPlan Regression \
  -destination "$destination" -derivedDataPath "${DERIVED_DATA_PATH:-$repo_root/.build/Regression}" \
  -resultBundlePath "$result_path" -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test "$@"
