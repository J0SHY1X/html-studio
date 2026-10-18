#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache"
TEST_DEVELOPER_DIR=$(xcode-select -p)
TEST_FRAMEWORKS="$TEST_DEVELOPER_DIR/Library/Developer/Frameworks"
typeset -a TEST_FLAGS
TEST_FLAGS=()
if [[ -n ${SDKROOT:-} ]]; then
  TEST_FLAGS+=(--sdk "$SDKROOT")
fi
if [[ -n ${HTML_STUDIO_SWIFT_BUILD_SYSTEM:-} ]]; then
  TEST_FLAGS+=(--build-system "$HTML_STUDIO_SWIFT_BUILD_SYSTEM")
fi
# Command Line Tools ships Swift Testing outside the SDK's default search path.
if [[ -d "$TEST_FRAMEWORKS/Testing.framework" ]]; then
  TEST_FLAGS+=(-Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS"
    -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS"
    -Xlinker -rpath -Xlinker "$TEST_DEVELOPER_DIR/Library/Developer/usr/lib")
fi
swift test --disable-xctest --disable-sandbox --package-path "$PROJECT_ROOT" \
  --cache-path "$PROJECT_ROOT/.build/cache" \
  --config-path "$PROJECT_ROOT/.build/config" \
  --security-path "$PROJECT_ROOT/.build/security" "${TEST_FLAGS[@]}"
