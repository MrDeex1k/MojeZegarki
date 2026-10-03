#!/bin/bash
set -euo pipefail
if [[ "${1:-}" == "--check" ]]; then
  xcrun swift-format lint --strict --recursive MojeZegarki Tests UITests
else
  xcrun swift-format format --in-place --recursive MojeZegarki Tests UITests
fi
