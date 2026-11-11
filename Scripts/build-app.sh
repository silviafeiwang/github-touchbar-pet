#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

sdk_path="${COMMIT_PET_SDK:-}"
if [[ -z "$sdk_path" ]]; then
  if [[ -d /Applications/Xcode.app ]]; then
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    # Some macOS 26 Command Line Tools releases ship a compiler/26.x SDK
    # version mismatch. The bundled 15.4 SDK remains compatible with Swift 6.
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
  else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  fi
fi

mkdir -p "$project_dir/.build/clang-cache" "$project_dir/.build/swift-module-cache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/swift-module-cache"
export SDKROOT="$sdk_path"

swift build --disable-sandbox --sdk "$sdk_path" -c release

app_dir="$project_dir/Build/Commit Pet.app"
contents_dir="$app_dir/Contents"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/CommitPetTouchBar" "$contents_dir/MacOS/CommitPetTouchBar"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
chmod +x "$contents_dir/MacOS/CommitPetTouchBar"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
