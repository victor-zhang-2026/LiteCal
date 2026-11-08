# LiteCal 1.2.5

- Date: 2026-11-09
- Version: 1.2.5
- Build: 11
- Bundle ID: app.litecal.mac
- Architecture: arm64
- Minimum macOS: 13.0
- Artifact: LiteCal-1.2.5-macOS-arm64.zip
- SHA-256: 6cbfa9a889791b3a53ced3185ce7458d6396af3c991eac3cef3a5daa052fa6c2
- Signing: ad-hoc; not Apple-notarized.

## Changes

The shared month/week date cell shows seven Gregorian festivals, nine traditional lunar festivals and all 24 solar terms in its existing lunar label. Solar-term dates are stored offline from the Hong Kong Observatory's UTC+8 annual conversion tables for 1901–2100. Festivals take precedence over solar terms. No event schema or storage change.

## Validation

The Release build compiled and passed strict bundle-signature verification. The extracted ZIP has version 1.2.5 (11), contains an arm64 executable and matches the build files. Production JSON files were unchanged during local installation. Per user instruction, no functional or UI tests were run; the user will perform acceptance.
