# LiteCal 1.2.1 release manifest

- Date: 2026-10-29
- Version: 1.2.1; build: 6
- Bundle ID: app.litecal.mac
- Artifact: `LiteCal-1.2.1-macOS-arm64.zip`
- Architecture: arm64 (Apple silicon)
- Deployment target: macOS 13.0
- UI: Simplified Chinese
- Signing: ad-hoc; no Developer ID signature or Apple notarization
- License: MIT
- SHA-256: `0825ecd8106f87a81e523d6618c2fd869c5255d2470b8f066fda79a5ed3a534a`

## Changes

Compact Monday-first week view, a month/week segmented control, remembered view selection, date-aware navigation and adaptive week height. A shared 0.23-second native animation moves the selection background, reused date views and panel height while keeping the window top and width stable. Event segmentation is recalculated against the target range; multi-day continuation markers and recurring occurrences retain their original semantics.

Existing month layout, shared event editor, drag and delete paths, floating trigger and schema 3 event storage are retained. Updating from 1.2.0 requires no data migration. Legacy schema 1/2 still uses the established immutable-backup migration.

## Validation

- 16,690 core assertions: civil/lunar dates, 2,412 months, four years of week boundaries, recurrence, persistence, migration and failure protection.
- 310 existing native assertions: month calendar, editor, selectors, drag behavior, hover/dismissal handlers, recurring series and confirmation paths.
- 716 week-view assertions: date continuity, exact clipped columns and continuation flags, overflow, shared operations, rapid switching, preference persistence and source-file byte preservation.
- Thirty animation samples show intermediate window heights, selection-background positions and reused date-cell positions; the window top, width and opacity remain stable.
- Four month-grid sizes match the preceding release's grid pixels exactly outside the changed header.
- Actual desktop mouse checks: create, edit, right-click delete, single-day and multi-day dragging, next-week clipping, Today, three switch cycles and a full process restart restoring week mode.
- Release source files match the tested feature implementation; only version metadata and public documentation changed for publication. Final package signature and archive integrity are verified before release.

## Evidence boundaries

Tested on Apple silicon / macOS 27.0.1, using Swift 6.4 and the macOS 26.5 SDK. Physical multi-display/scaling combinations, older macOS releases, exhaustive hover/outside-click combinations and video frame-rate measurement remain outside full coverage. Original native handler tests cover hover/dismissal behavior. No production schedule is included in tests or release screenshots.
