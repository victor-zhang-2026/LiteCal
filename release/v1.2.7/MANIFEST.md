# LiteCal 1.2.7

- Date: 2026-11-11
- Version: 1.2.7
- Build: 13
- Bundle ID: app.litecal.mac
- Architecture: arm64
- Minimum macOS: 13.0
- Artifact: LiteCal-1.2.7-macOS-arm64.zip
- SHA-256: 72b770b420f5fb0cc458eb789755d2064903d09658cdaa719246c6b536511261
- Signing: ad-hoc; not Apple-notarized.

## Changes

The month/week control supports a click or a drag. Its light gray frosted selection slides before the calendar view changes, and the active label is purple. The month and vertical week layouts, event schema and storage are unchanged.

## Validation

The user accepted this interaction in the locally installed 1.2.6 (12) app. The 1.2.7 (13) release executable has identical unsigned bytes to that installed app; signing differs because the bundle version changed. The Release build passed strict signature verification. The extracted ZIP passed CRC, version, architecture, signature, executable permission and build-byte checks. No new automated functional or UI tests were run. Older macOS and physical multi-display combinations remain outside current coverage.
