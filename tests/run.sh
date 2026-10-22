#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")/.." && pwd)"
sdk="${SDKROOT:-$(xcrun --show-sdk-path)}"
mkdir -p "$source_dir/.build"
swiftc -sdk "$sdk" "$source_dir/TriggerZones.swift" "$source_dir/tests/geometry.swift" -o "$source_dir/.build/test-geometry"
"$source_dir/.build/test-geometry"
if [[ "${1:-}" == --integration ]]; then
    swiftc -sdk "$sdk" "$source_dir/tests/drive-edge.swift" -o "$source_dir/.build/drive-edge"
    python3 "$source_dir/tests/test-switching.py"
fi
