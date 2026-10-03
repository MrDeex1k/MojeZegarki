#!/bin/bash
set -euo pipefail
# Supply a UUID from xcrun simctl list devices available, or a complete destination.
: "${IOS_DESTINATION:?Set IOS_DESTINATION, e.g. platform=iOS Simulator,id=UUID}"
result_path="${RESULT_PATH:-.build/Regression-$(date +%Y%m%d-%H%M%S).xcresult}"
xcodebuild -project MojeZegarki.xcodeproj -scheme MojeZegarki \
  -destination "$IOS_DESTINATION" -derivedDataPath "${DERIVED_DATA_PATH:-.build/Regression}" \
  -resultBundlePath "$result_path" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 240 CODE_SIGNING_ALLOWED=NO test "$@"
