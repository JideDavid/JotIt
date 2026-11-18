# AI and PIN release verification

Updated 2026-11-17. Physical-device checks require the Redmi to appear as an authorized device in `adb devices -l`; a USB device entry in Windows alone is insufficient.

## Automated evidence

- Release-readiness check (2026-11-17): full serial Flutter suite **272 passed**;
  project-wide analysis clean; browser startup **15 passed**; preview-server
  regression passed. The sample web release rebuilt successfully. An isolated
  browser origin at `http://127.0.0.1:7369/` renders the library and settings;
  recovery correctly reports that its service is not configured. This preview
  uses sample storage and does not enable live accounts, recovery or AI.
- The Android arm64 release APK builds and verifies with the existing **Android
  Debug** certificate. It is suitable for the current local testing setup;
  production signing and a version-code increase are required before store
  distribution. Physical-device checks below remain outstanding.

- Native editable headings, lists, checklists, stickers and doodles; selected-text offsets; whole/new/append restrictions; links and object preservation; stale/locked/switched note rejection; atomic Apply and Undo: `note_ai_test.dart`, `note_ai_refinements_test.dart`, `firebase_note_ai_test.dart`.
- Progress stages, bounded correction, interrupted sign-in, cancellation during generation, late results and total timeout: `note_ai_request_test.dart`. The narrow-screen workspace test in `note_ai_test.dart` stops a follow-up, retains the last draft and applies/undoes it safely.
- Existing PIN record compatibility, native dispatch, wrong PIN, invalid records, automatic fourth-digit submission and duplicate attempt prevention: `pin_hasher_test.dart`, `pin_auto_submit_test.dart`. Native Java compatibility is independently verified by `test/java/PinKeyDerivationTest.java`.

## Phone checks still to complete

1. On the latest release, Format a synthetic note, Refine selected text, Create on an empty note, and add a checklist plus a catalog sticker/doodle. Inspect Original/Proposed, follow up, Apply, Undo and reopen saved notes.
2. Stop waiting during a follow-up and confirm the earlier draft remains usable. Retry after a connection failure; check locking/backgrounding never reveals or applies a late result.
3. Scroll long highlighted text with the keyboard open and closed. Check toolbar actions, floating undo/redo and bottom navigation safe areas.
4. Measure App Lock and note-lock latency from the fourth digit for correct and incorrect PINs. Check background relocking and cooldowns. Use the separate synthetic benchmark in `pin-performance.md` to distinguish crypto time from full UI/storage time.

The owner confirmed that Make it more colorful works on mobile after the heading-preset fix. Captured empty-note Create responses replay successfully after the insertion fix. This does not establish that every live mode or the new lifecycle UI has passed phone testing. No target-device latency is claimed without measurements.
