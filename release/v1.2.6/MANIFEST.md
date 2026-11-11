# LiteCal 1.2.6

- Date: 2026-11-11
- Version: 1.2.6
- Build: 12
- Bundle ID: app.litecal.mac
- Architecture: arm64
- Minimum macOS: 13.0
- Artifact: LiteCal-1.2.6-macOS-arm64.zip
- SHA-256: f6d46bfb62602ab996ac02c43860e2ea8d962f064f2f43be03461a301a23190e
- Signing: ad-hoc; not Apple-notarized.

## Changes

The week view presents Monday through Sunday in seven vertical rows. Each row displays weekday, Gregorian and lunar dates, and all daily events. Rows grow with their contents, and the week area scrolls when needed. Month/week switching gently resizes the floating panel while blending the outgoing and incoming views. Month layout, event schema and storage are unchanged.

## Validation

The user accepted the vertical week view and final transition in the locally installed 1.2.5 (11) build. The 1.2.6 (12) build has identical unsigned executable code and updated version metadata and signature. The Release build compiled and passed strict signature verification. The extracted ZIP passed CRC, version, architecture, signature, executable and build-byte checks. No new automated functional or UI tests were run; older macOS and physical multi-display combinations remain outside current coverage.
