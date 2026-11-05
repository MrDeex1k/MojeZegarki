#!/bin/bash
set -euo pipefail
CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.."
case "$#:${1:-}" in
  0:) exec xcrun swift-format format --in-place --recursive MojeZegarki Tests UITests ;;
  1:--check) exec xcrun swift-format lint --strict --recursive MojeZegarki Tests UITests ;;
  *) printf 'Usage: bash scripts/format.sh [--check]\n' >&2; exit 2 ;;
esac
