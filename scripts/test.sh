#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
sdk="${LITECAL_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
mkdir -p build qa/core-data
swiftc -sdk "$sdk" Sources/LiteCal/CalendarModel.swift Sources/LiteCal/EventStore.swift Sources/LiteCal/Placement.swift Sources/LiteCal/EventLayout.swift Tests/CoreTests.swift -o build/core-tests
build/core-tests "$PWD/qa/core-data"
