#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
sdk="${LITECAL_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
mkdir -p build
sources=(Sources/LiteCal/*.swift)
sources=(${sources:#*/main.swift})
swiftc -sdk "$sdk" -swift-version 5 "${sources[@]}" Tests/NativeTests.swift -o build/native-tests
mkdir -p qa/v1.1
build/native-tests "$PWD/qa/v1.1"
