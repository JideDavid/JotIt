# JotIt

A Flutter note-taking app with local Hive storage, note search and colors,
Google sign-in, and optional PIN and biometric app locking.

Native note assistance uses Firebase AI Logic with App Check. See the
[Firebase AI setup guide](docs/firebase-ai-setup.md) for console registration,
signing fingerprints and release testing. No Gemini key or local computer is
required by the Firebase release build.

Shared note PIN recovery has a configurable email backend and an in-app
enrollment/reset flow. It stays unavailable until a recovery endpoint and verified
sender are configured. See the [recovery setup guide](docs/note-pin-recovery.md)
for activation, deployment and testing requirements.

Cloud backup/restore and cross-device sync have a local implementation with
explicit account connection, offline saves, conflict copies and 20 retained
backup revisions. Live use needs a configured private backend and Cloudflare R2
bucket; Firebase stays on Spark.
See [cloud backup and sync](docs/cloud-backup-sync.md) for behavior and activation.

## Development

The project requires Dart 3.11 or later through a compatible Flutter SDK.
Validation currently uses Flutter 3.44.6 and Dart 3.12.2.

```sh
flutter pub get
flutter analyze
flutter test
```

For device runs, supply the existing Firebase project's configuration files:
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
These files are ignored by Git. Windows plugin setup may require Developer Mode
for symlink support. Unit and widget tests use local fakes and temporary Hive
boxes, so they do not require a Firebase project or biometric hardware.

## Browser preview

To explore the UI without Firebase configuration:

```sh
flutter run -d chrome -t lib/preview.dart
```

The preview seeds sample rich-text notes once and uses separate local storage.
Editing, saving, searching, note colors, and PIN locking use the actual app code.
Google sign-in is unavailable, and device biometrics require a native device run.

For a faster, stable preview without the debug module loader:

```sh
flutter build web --release --no-pub -t lib/preview.dart --no-web-resources-cdn --no-wasm-dry-run
python -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:7357/`. Keep the server running, and rebuild then refresh
after code changes. Use the same address and port to retain browser-saved notes
and PIN settings. Engine resources are served locally rather than from a CDN.
The browser shows a loading screen until Flutter's first frame, with retry
feedback if startup fails or takes too long. It never resets saved notes.
Run the startup-screen regression tests with `node --test test/web_startup_test.cjs`.

## Appearance

Choose **Settings → Appearance → System / Light / Dark**. The selection is saved
locally and applies to the library, editor, security screens, dialogs and startup.
New installations follow the device appearance; existing local installations
keep Dark on their first upgrade. A failed preference write leaves the previous
appearance intact. Switching appearance never rewrites notes, rich-text colors,
paper settings or PINs, and does not unlock protected content.

Quiet paper uses warm neutral light surfaces, layered charcoal dark surfaces,
amber actions, and theme-paired note cards. The editor remains bounded on wide
screens and keeps its formatting rail above the keyboard. Email recovery needs
a configured service; backup and sync also require separate configuration and
explicit connection to your account.

## Reliability behavior

- Notes are displayed by most recent update, with a stable ID tie-breaker.
- Search filters titles and bodies; an unmatched query displays no results.
- Saves and deletes report success only after storage completes. Failed writes
  retain saved data and editor drafts for retry. Repeated save taps cannot
  create duplicate notes.
- Leaving an edited note prompts to save or discard, including color-only
  changes and clearing existing text. A failed save keeps the editor open.
- App Lock is restored at startup and activated whenever the app becomes hidden
  or paused. Unlocking restores the open screen, dialogs, and unsaved draft.
  Temporary inactive states, such as biometric prompts, do not relock the app.
- Disabling App Lock requires the current PIN and clears biometric preferences.
  Five incorrect unlock attempts trigger a 30-second cooldown for that session.
- PINs use salted PBKDF2-HMAC-SHA256 hashes with 600,000 iterations. Existing
  plaintext PINs migrate after successful verification. PINs and tokens are
  excluded from debug logs. App locking does not encrypt the note database.

Notes are stored on the device. A configured and explicitly connected cloud
service can back up saved notes and sync them to the same account's devices.

## Individual note locks

Open a note and choose **Note actions → Lock note**. The first lock
sets a shared four-digit note PIN; later locks use that same PIN. Locking saves
the current draft. This PIN is independent of App Lock and remains available
when App Lock is disabled. Keep it safe: recovery requires prior enrollment and
a configured recovery service. An unenrolled forgotten PIN cannot be recovered.

Locked cards hide their title and body and do not match searches. Opening or
deleting a locked note requires the note PIN. To remove protection, unlock the
note and choose **Note actions → Remove note lock**, confirming the PIN again. Access ends when
you leave the editor or the app becomes hidden/paused. Reopening requires the
PIN; background re-locking preserves unsaved drafts and hides editor dialogs.
Five incorrect attempts trigger a shared 30-second session cooldown.

The shared PIN is stored as a salted PBKDF2 hash. These locks provide in-app
access control, not encryption of the local note database or future backups.
Existing notes with a lock flag but no note PIN prompt to set the shared PIN.

## Rich-text notes

JotIt uses the approved purple folded-note J as its app identity. The symbol
appears in the library, account and startup screens, with matching launcher and
browser/PWA icon assets. Source artwork and export instructions are recorded in
`assets/branding/logo-design.md`.

The note body supports bold, italic, underline, strikethrough, text color,
highlighting, links, headings, font sizes, bulleted and numbered lists,
checklists, and quotes. The rounded formatting rail sits at the bottom of the
editor, above the keyboard. Swipe or drag its single row of buttons horizontally,
or use the arrow buttons, to reach all formatting tools. Undo and redo stay directly accessible in
a small floating control above the rail. Select text to style it,
or activate a style before typing. The title remains plain text.

Use **Font family** on the rail to preview ten Google Fonts, from bold poster
faces like Anton, Archivo Black and Bungee to geometric Space Grotesk, editorial
serifs and handwritten styles. Filter by style, preview your selection, then
choose **Apply font**. **Use default** restores the default family. Fonts work
offline and remain part of the note's rich text alongside bold, italic and color.

Text highlights use a distressed marker stroke with speckled edges and visible
padding at both ends of every wrapped line. Existing highlight colors keep
working; the brush treatment is visual and adds no characters to saved notes.

Choose **Note actions → Note card color** to change the note card's color. Text
color and highlighting apply separately to the selected body text. Links can
use HTTP, HTTPS, or mailto; website addresses without a scheme use HTTPS.

Formatting is stored as a Quill Delta in the optional Hive field 6. The existing
body field remains plain text for search and previews. Existing six-field
notes are supported without a destructive migration; they gain a rich-text
document when edited and saved. Formatting-only changes use the same save,
discard, and failed-write protections as text edits.

## Note paper styles

Open a note and tap **Paper style** (the texture icon beside Save). Choose Plain,
Dotted, Ruled, Grid, Diamond, or Soft wash, then customize the paper tone,
pattern spacing, and intensity. The live preview is temporary until **Apply paper**;
Cancel or dismiss leaves the note unchanged. Use **Save note** to persist the choice.

Paper is saved per note in optional Hive field 7, independently of the library
card color and rich-text formatting. Older notes default to plain paper without
a destructive migration. Tones adapt to the app theme. Patterns scroll with the
body; ruled lines are decorative rather than a baseline grid for headings/lists.
Background-only edits use the existing save/discard and failed-write protections.

## Regression coverage

The tests cover search-result deletion, failed and delayed persistence,
duplicate-save prevention, stable sorting, editor exit flows, storage cleanup,
PIN migration, biometric fallback, and background locking with open editors
and dialogs. Native biometric prompts still require device testing.
Individual-lock tests cover shared PINs, hidden search results and previews,
authenticated deletion/removal, failed writes, cooldowns, stale authentication,
independence from App Lock, and background re-locking with unsaved rich text.
