#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

sdk_path="${COMMIT_PET_SDK:-}"
if [[ -z "$sdk_path" ]]; then
  if [[ -d /Applications/Xcode.app ]]; then
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
  else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  fi
fi

mkdir -p "$project_dir/.build/clang-cache" "$project_dir/.build/swift-module-cache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/swift-module-cache"
export SDKROOT="$sdk_path"

swift run --disable-sandbox --sdk "$sdk_path" CommitPetTouchBar --self-test
