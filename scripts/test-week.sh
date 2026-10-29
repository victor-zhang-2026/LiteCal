#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
sdk="${LITECAL_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
sources=(Sources/LiteCal/*.swift)
sources=(${sources:#*/main.swift})
mkdir -p build qa/week-view
swiftc -sdk "$sdk" -swift-version 5 "${sources[@]}" Tests/WeekViewTests.swift -o build/week-tests
build/week-tests "$PWD/qa/week-view"
