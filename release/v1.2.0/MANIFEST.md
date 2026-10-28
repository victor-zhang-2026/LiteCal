# LiteCal 1.2.0 release manifest

- Date: 2026-10-28
- Version: 1.2.0; build: 5
- Bundle ID: app.litecal.mac
- Artifact: `LiteCal-1.2.0-macOS-arm64.zip`
- Architecture: arm64 (Apple silicon)
- Deployment target: macOS 13.0
- UI: Simplified Chinese
- Signing: ad-hoc; no Developer ID signature or Apple notarization
- License: MIT
- SHA-256: `4faccfa8bf24cbdb4f41024027015f6f4f5a5247b71d36e7f621f3e82b56e3d6`

## Changes

Fixed daily, weekly, monthly and yearly recurrence. Existing events default to no repeat. Monthly/yearly occurrences clamp missing dates to month end and retain the original anchor for later occurrences. Multi-day duration is preserved. Editing/deletion affect the whole series; dragging shifts its original range before recalculating occurrences. No custom intervals, end conditions or per-occurrence exceptions.

Schema 1/2 upgrades to schema 3 after an immutable original-byte backup. Older app versions reject schema 3. Restore a matching old backup only after preserving the full current data directory if downgrading.

## Validation

- 12,304 core assertions covering civil/lunar dates, 2,412 months, recurrence, overlap/overflow, bounds, persistence, migration and failure protection.
- 310 native AppKit assertions covering controls, saved frequencies, cancellation, future-occurrence editing, series deletion, date pickers, drag behavior and layout.
- Debug and Release builds completed; strict ad-hoc signature verification passed.
- Actual desktop checks with an isolated QA copy of the Release: new event, five-option menu, monthly save, next-month occurrence and original-series edit.
- Native view snapshots inspected for the recurrence editor and overlapping daily ranges.

## Evidence boundaries

Validated on Apple silicon / macOS 27.0.1 with Swift 6.4 and the macOS 26.5 SDK. Older supported systems, physical multi-display/scaling combinations and overnight operation were not repeated. Daily/weekly/yearly selection and recurrence edge cases are covered by automated core/native tests; manual desktop repetition focused on monthly recurrence. SDK linker warnings referenced absent optional toolchain search directories; both builds and signature checks succeeded.
