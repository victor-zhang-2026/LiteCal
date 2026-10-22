#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-debug}"
sdk="${LITECAL_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
swift build -c "$configuration" --sdk "$sdk"
bin_dir="$(swift build -c "$configuration" --sdk "$sdk" --show-bin-path)"
bundle="${LITECAL_BUNDLE_DIR:-build/LiteCal.app}"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_dir/LiteCal" "$bundle/Contents/MacOS/LiteCal"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
if [[ -f Resources/LiteCal.icns ]]; then cp Resources/LiteCal.icns "$bundle/Contents/Resources/"; fi
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
echo "$PWD/$bundle"
