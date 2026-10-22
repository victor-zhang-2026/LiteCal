# LiteCal 1.1.0 release manifest

- Date: 2026-10-22
- Version: 1.1.0; build: 4
- Bundle ID: app.litecal.mac
- Artifact: `LiteCal-1.1.0-macOS-arm64.zip`
- Architecture: arm64 (Apple silicon)
- Deployment target: macOS 13.0
- UI: Simplified Chinese
- Signing: ad-hoc; no Developer ID signature or Apple notarization
- License: MIT
- SHA-256: `410e95272d7231b8eb53f3f012ceca87865c8dd7bcccb291b552e92ebb083a53`

## Validation

This release uses the accepted local build 4 unchanged. ZIP bytes match the previously delivered test ZIP; only the published filename differs. Debug and Release builds completed, and code-sign verification passed.

- 11,766 core assertions: civil/lunar dates, 2,412 months, persistence, migration and failure protection, weekly event layout and geometry.
- 276 native assertions: AppKit windows/controls, create/edit/delete, date ranges, drag movement, keyboard scope, hover styling and local mouse-event dispatch for click-to-keep/outside dismissal.
- Final Release launched with an isolated data directory.
- Marketing uses fictional events exported from real AppKit views; no personal event files are included.

## Evidence boundaries

Tests ran on Apple silicon with macOS 27.0.1, Swift 6.4 and the macOS 26.5 SDK. Older supported OS versions, physical multi-display/scaling combinations and overnight continuous operation have not all been validated. The latest click/drag refinements were covered by native handler/event tests; they were not all repeated with a physical pointer before release. Earlier iterations had desktop create/edit/delete/drag/restart checks.

No reminders, recurrence, cloud sync, external calendar connection, English UI or Windows build are included. Drag targets are limited to currently visible dates; use the editor for other months.
