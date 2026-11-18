# JotIt UI audit and implementation plan

Date: 2026-11-13; completion audit: 2026-11-14. Status: Quiet paper implemented
and locally verified; target-device release checks remain separate.

## Implementation progress

### Cloud backup and cross-device sync — local implementation (2026-11-17)

Account opt-in, a private Firebase-authenticated/App-Check backend, snapshot
history, non-destructive restore and offline three-way sync are implemented
locally. Locked notes are included; PINs remain local. This is account-based
cloud access, not end-to-end encryption. Hosting, private Storage/Firestore,
billing approval, retention operations and real two-device verification remain
activation work. See `cloud-backup-sync.md`. Older planned-status text below is
historical and does not describe this new implementation.

### Shared note PIN recovery — local implementation (2026-11-17)

Enrollment, reset, unlinking, native PIN envelope migration, and a separate Firebase-authenticated/App-Check-protected recovery backend are implemented and tested locally. Live delivery remains disabled pending HTTPS hosting, server-only Firestore access and a verified email sender. The recovery page reports this configuration state truthfully. See `note-pin-recovery.md` for activation, protocol constraints and test evidence. Earlier recovery sections below record the product plan; they do not imply live email is enabled. App Lock recovery and cloud sync remain separate milestones.

### Follow-on phase 1: optional account sign-in (2026-11-14)

The account flow now restores the Firebase SDK session, observes user changes,
distinguishes cancellation from connection/configuration failures, and offers
confirmed sign-out without deleting local notes, attachments or PIN preferences.
Missing Firebase initialization falls back to local-only access; the sample
preview explicitly disables live accounts. Google sign-in and the existing APK's
SHA-1/SHA-256 certificates were configured in project `jotit-ab937` with the
owner's approval. The owner's fresh Android configuration was validated for the
project, package, both OAuth client types and signing certificate, then installed
in the ignored app configuration path. A physical-device login check remains
required before certifying live authentication. Cloud sync and PIN recovery
remain planned.

The configured Android release APK rebuilt and passed signature/resource checks
with the correct OAuth client packaged. The sample web preview also rebuilt
with live sign-in intentionally disabled. Two additional offline/late-result
regressions pass in the focused 27-test account/service run.

The full serial Flutter suite passes 190 tests, including the new account and
SDK-fake regressions. A concurrent run hit two formatting-sheet UI timing
failures; the targeted UI run and the full serial run pass. The analyzer still
reports only the pre-existing unused import in `lib/shared/widgets/tab_button.dart`.
See `account-sign-in.md` for behavior, configuration and platform limitations.

The user approved Quiet paper, light/dark appearances, the bottom formatting rail,
and customizable per-note paper styles. The audit below records the baseline,
not the current state of every implementation detail.

Implemented in the current worktree:

- Persisted System / Light / Dark appearance, defaulting new installs to System
  and migrating existing local installations to Dark. Failed preference writes
  keep the previous appearance and report a retryable error.
- Shared semantic colors, typography, amber actions, field/dialog/menu treatments,
  and paired note-card surfaces and color markers for both appearances.
- Quiet paper library and settings, explicit note actions and deletion confirmation,
  private locked cards, bounded reading layouts, and scrollable large-text headers.
- Optional account and biometric screens, app-unlock styling, PIN dialog spacing,
  persistent editor save status and labeled Save, and appearance-aware web startup.
- Existing per-note paper customization and bottom formatting rail are integrated.
  Theme changes retain unsaved Quill content, explicit formatting and lock state.
- Six common formatting controls remain visible in the bottom rail, with a
  labeled advanced sheet. Heading/font-size dialogs preserve selected text.
- Dedicated shared-note unlock, separate app-unlock scope, explicit security
  actions and automatic fourth-digit unlock checks retain the manual buttons.
- Unlocked tinted cards echo saved paper patterns; locked cards stay neutral.
- Custom note-card colors use a wheel, brightness, precise sliders and hex input,
  with 24 persist-first favorites. Original preset indices and note fields stay
  compatible; derived light/dark tints preserve readable foregrounds.
- The separately approved Inline story media extension is implemented in the
  worktree. See `media-notes.md` for local storage, limits and device-test caveats.

The Quiet paper completion audit below covers the original UI objective and the
subsequently approved card-color/media extensions. Issues found during the audit
were fixed: narrow keyboard-open PIN dialogs now scroll, image actions are
labeled, images retain their full aspect, playback stream failures are handled,
and consecutive attachments occupy atomic, undoable paragraphs without splitting
the following text. No known UI implementation gate from this audit remains.

Separate release checks: physical biometric/microphone permissions, native builds
and native codecs still require target-device testing. Local widget/plugin-fake
regressions and browser tests do not certify hardware support.

Verified-email PIN recovery remains a separate backend-dependent planned flow.
Current account/recovery screens explicitly say that no recovery email is sent.

Latest completed validation: 161 Flutter regressions, 15 browser-startup tests,
and the loopback preview-server regression pass. The release preview has rebuilt
successfully with the paragraph-safe attachment insertion fix.
Analyzer output contains only the pre-existing unused import in
`lib/shared/widgets/tab_button.dart`. A separate fresh-origin browser review
confirmed the light/dark library, settings and editor without touching the
user's preview notes or PIN.

## Final audit evidence — 2026-11-14

| Requirement | Current evidence |
| --- | --- |
| Persist System/Light/Dark and migrate safely | `appearance_test.dart` covers initialization, migration, persist-first failure/retry, System changes and lock invariants; Hive reopen tests verify storage. Browser reload retained Dark. |
| Readable semantic typography, surfaces and amber actions | Contrast regressions cover every preset plus 216 RGB custom-color samples in each appearance. Actual library/settings/account/editor browser captures and paired widget renders cover light/dark treatments. |
| Library layout, empty/search/private cards | `appearance_test.dart`, `widget_test.dart`, `note_card_paper_test.dart` cover small widths, text scaling, search, redaction, all paper patterns and neutral locked custom-color cards. Browser saved/reloaded a custom patterned tint without changing text/media. |
| Bottom editor rail and paper customization | Six-tool rail, advanced formatting and selection retention are exercised in both appearances. Keyboard-open 320x640 tests retain the bottom rail. Existing paper picker save/discard/lock regressions pass. Actual browser paper sheet shows all six styles and note-only scope. |
| PIN, forms, dialogs, account and biometrics | `quiet_ui_test.dart` renders both appearances, 1.6x text and keyboard-open PIN forms, including reachable fields. Fourth-digit authentication, duplicate protection, retries, explicit destructive confirmation, and background gates have dedicated regressions. Account and biometric fixtures render without enabling real permissions or changing credentials. |
| Preserve notes, Delta and reliability | Hive backwards-compatibility and reopen tests, rich-text, saving/pending/failure, deletion/search/sort, and app/shared-note lock suites run together. Attachment insertion now uses one atomic Delta with paragraph boundaries, retained styles and one-step undo. |
| Startup and rebuilt preview | Startup tests cover appearance mirrors, slow/failing boot, retry without clearing storage, and cache-safe entrypoint/assets. The final release build verifies all media web plugins. A post-build browser reload restored saved text, two images, two audio files, custom tint, dotted paper and favorite #2D7D9A on an isolated sample origin. The user's existing port 7357 returns HTTP 200 and serves the matching 4,415,205-byte build with no-store headers, without reloading their tab. |
| Recovery stays planned, not a client bypass | Settings/account/PIN copy explicitly states recovery is unavailable. No mail sending, PIN reset endpoint, client-only verification grant or embedded email-service credential was introduced. |

Audit artifacts are generated under `.dart_tool/ui-audit` (ignored, not note
storage). To regenerate paired UI frames with readable SDK fonts, run:

```powershell
flutter test --no-pub --dart-define=JOTIT_UI_AUDIT=true --dart-define=JOTIT_AUDIT_FONTS=C:/dev/flutter/bin/cache/artifacts/material_fonts test/quiet_ui_test.dart
```

The font directory is a test-only parameter; it is not an application dependency.
The default test run retains Flutter's test font. Quill's own fallback can still
appear as blocks in test frames; real browser captures verify authored text.
The in-app browser viewport override did not change its reported 1280x720 size,
so phone/keyboard claims use the actual 320x640 Flutter widget tests, not an
ineffective browser resize.

Browser media evidence: actual PNG import, enlarged preview, WAV upload,
30-second duration, playback, pause and keyboard seek all work on the isolated
sample origin. Automation uploads require normalized forward-slash paths;
backslash paths produced empty input and a standalone file probe crashed.
This does not justify accepting empty files or bypassing size validation.
Physical microphone/biometric permissions, native codecs and native builds still
need target-device release checks; no real PIN, account or microphone was used.

## Scope and evidence

This is a source-level audit of every current screen and shared dialog, informed
by the existing browser preview. It is not a claim that every native page has
been exercised on hardware. The proposed interactive mockups use sample data,
do not change application settings, and do not send email.

## Highest-priority findings

1. Light mode exists as theme definitions but is not selectable or applied:
   `lib/main.dart:51` always uses `LSTAppTheme.darkTheme`. No persisted appearance
   choice or system-theme handling exists.
2. Changing that one assignment would not fix the UI. Homepage, settings,
   keypad, splash, and shared icon buttons explicitly use dark surfaces/white
   text. Note-card foregrounds inherit the app theme rather than the card color.
3. Contrast defects already exist in dark mode: `text_theme.dart:41` converts
   `0.5` to zero alpha, making medium labels transparent; the dark app-bar leading
   icon is black (`appbar_theme.dart:25`); locked-card icons use black on dark note
   fills (`homepage.dart:220`). Dark field labels/hints also need review.
4. Typography is inconsistent: 40px library title, 26px editor title, 10px update
   labels, and a declared HelveticaNowDisplay family with no registered font
   assets in `pubspec.yaml`. Avoid relying on an unavailable font.
5. Primary actions and security vocabulary lack a single system. App PIN and
   shared note PIN need visibly different scopes without looking unrelated.
6. Email recovery is agreed but unimplemented. The existing setup message
   correctly still says there is no recovery; do not replace it with a promise
   until a verified backend flow works.

## Page-by-page audit

| Screen / state | Current finding | Proposed realignment |
| --- | --- | --- |
| Notes library (`features/notes/view/homepage.dart`) | Large white heading, dark-only search, saturated cards, tiny timestamps; delete is discoverable only through long press. | Balanced header, clear search, legible metadata, theme-aware cards, explicit overflow action plus long press. Keep creation prominent. |
| Locked cards | Content is correctly redacted; black lock icon can disappear on dark fills. | Neutral private card, high-contrast lock, “Locked note” and “PIN required”; never preview titles/body or match hidden text in search. |
| Empty library | Large unconstrained illustration can compete with or overflow available space. | Compact illustration/icon, helpful copy, primary “Create note”; flexible at small heights and large text. |
| No search results | Functional but visually similar to initial empty state. | Query-specific “No matching notes”, clear-search action; do not imply notes were deleted. |
| Note editor (`features/notes/view/note_page.dart`) | Several icon-only header actions; all formatting is one long horizontal strip. Save feedback is transient. | Label the Save action; persistent saved/unsaved/saving/failed state; group security/card color in overflow. Keep common formatting visible and put advanced options in a clearly labeled sheet. |
| Rich-text tools (`view/widgets/rich_text_toolbar.dart`) | Tooltips exist, but later features require horizontal discovery; text colors can become unreadable across themes. | Text/paragraph/insert groups, selected-style states, labeled swatches, clear reset. Preserve user-selected rich-text colors; do not rewrite stored Delta when switching appearance. |
| Settings (`views/settings_page.dart`) | Only two dark cards; lacks appearance, note-PIN management, account and recovery status. | Sections: Appearance, Security, Account & recovery. Distinguish app lock from note lock and explain unavailable biometrics. Mark cloud backup as planned, not connected. |
| App unlock (`auth/view/pin_login.dart`) | Dark-only keypad; all-caps generic security copy; no visible scope explanation. | Branded, calm keypad with “Unlock JotIt” and “App PIN”; biometric fallback and error/cooldown states. Do not add note-PIN recovery as an app-PIN bypass. |
| Note unlock (`auth/view/app_lock_gate.dart`, `notes/view/widgets/note_pin_prompt.dart`) | Alert-dialog presentation inside a separate full screen; repeated titles; little distinction from other PIN prompts. | Dedicated note-lock screen with “Shared note PIN”, compact single task, clear return path when safe; retain the gate that hides routes and dialogs. Add recovery only when enrolled and implemented. |
| App PIN setup/removal (`shared/widgets/pin_auth_modal.dart`) | Working validation, but not part of a consistent security visual system. | Shared form layout, clear app-specific headings, confirmation, progress and current-PIN verification. |
| Shared note PIN setup/removal/deletion | Working shared credential and persistence protections; recovery missing. | Same form grammar, explicit shared scope, verified recovery enrollment, action-specific confirmation. Preserve authentication for deletion and lock removal. |
| Save/discard dialog | Working but only Save/Discard buttons; no explicit “Keep editing”. | “Unsaved changes” sheet/dialog with Save, Discard, Keep editing; show failed-save retry without losing the draft. |
| Link and color dialogs | Functional, but need consistent field surfaces, selection indicators and spacing. | One form/dialog system, visible URL validation, labeled colors, selected marker, reset affordance and keyboard-safe actions. |
| Startup and web loading (`auth/view/splash_screen.dart`, `web/index.html`) | Circular splash plus fixed two-second wait; browser loader is fixed dark. | One wordmark/loading treatment; review artificial delay; appearance-aware browser startup without exposing notes before authentication. Preserve retry feedback. |
| Sign-in (`auth/view/login_page.dart`) | Sparse single button; signed-in branch is mostly a fingerprint icon. Startup currently routes directly to notes; sign-out can reach this page. | Optional account-connect screen explaining recovery and future sync. Keep local notes usable without an account; explicitly handle offline/cancel/error states. |
| Biometric introduction (`auth/view/enable_biometric_page.dart`) | Present in source but no current navigation reference found. Blue full-screen design and “transaction” copy do not fit notes; delayed pop is not tied to success. | Consolidate into Settings enrollment sheet unless a standalone page is approved. Explain device authentication, availability and fallback; only leave after the actual result. |
| Snackbars, menus, focus and selection | Several independent colors, radii and treatments. | Shared semantic success/error/info surfaces, readable actions, consistent keyboard focus and accessible names. |

## Design directions for approval

### Quiet paper — recommended

Warm neutral light canvas, charcoal text, restrained amber identity, pale note
surfaces with small color markers. Dark counterpart uses layered charcoal rather
than washed-out gray. A comfortable single-column library and distraction-free
editor prioritize reading and writing. No new folders, tags, AI features or
dashboard are implied.

### Color notebook — alternative

More expressive, theme-paired colored note tiles in a two-column library, with a
compact top formatting bar and stronger notebook character. Locked tiles remain
neutral and redacted. At narrow widths or large text sizes the grid becomes a
single column. This is a different layout, not just a different color palette.

Both directions retain existing note colors and editing capabilities. Sample
email, counts, verification states and notes in the mockups are design fixtures.

## Shared design-system plan

- Use semantic `ColorScheme` roles and a small theme extension for note-card
  background/foreground pairs, warning, success, selection and editor surfaces.
- Add persisted System / Light / Dark modes. Default to System for fresh installs;
  migrate existing installs to Dark to avoid an unexpected appearance change.
- Apply appearance to every route, nested gate, dialog, menu, field, toolbar,
  snackbar, selection and startup surface. Never unlock a note when changing it.
- Keep amber identity, with dark text on bright amber buttons in light mode.
  Use a supported system font or bundle a deliberately chosen licensed font.
- Standardize a 4/8px spacing rhythm, comfortable body text, meaningful headings,
  consistent radii and compact-but-readable metadata. Honor text scaling.
- Target 4.5:1 contrast for ordinary text, 3:1 for qualifying large text; test the
  actual background, including all nine note colors. Product touch controls target
  48 logical pixels; this is a comfort goal, not a claim about WCAG's minimum.
- Keep notes readable without changing explicit user-authored text/highlight
  colors. Offer a neutral page surface/reading option if an authored combination
  becomes unreadable; do not silently modify saved formatting.
- Use full-width layouts on phones, bounded reading widths on tablets/desktop,
  safe areas and keyboard-aware sheets. Do not stretch keypad or text indefinitely.

References: [W3C text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [W3C pointer-target guidance](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).
These are implementation targets, not a completed accessibility certification.

## Email recovery — agreed product direction, not yet implemented

No permanent recovery code is required. Never email or retain a recoverable copy
of the shared PIN. Email a short-lived, single-use reset link instead.

### Enrollment

1. Link an account and verify ownership of the recovery email.
2. Bind recovery to the correct account and local installation/lock identity.
3. For existing protected notes, require the current note PIN before enabling or
   replacing recovery. Do not let a person who forgot an unenrolled PIN attach
   an arbitrary email and bypass it.
4. Show clear Not linked / Verification pending / Verified / Unavailable states.
   Local users can continue using PIN locks, with an honest no-recovery warning
   if they decline enrollment. Never imply that email is already configured.

### Reset

1. “Forgot note PIN?” sends only to the previously verified address; show a masked
   address where appropriate, and use neutral responses on public endpoints.
2. A backend issues and verifies a cryptographically random, expiring, one-use
   token with request/attempt limits. No client-only “verified” flag or embedded
   email-service secret can authorize a reset.
3. After verification, allow a new shared PIN and confirmation. Consume the reset
   authorization atomically and reject expired, replayed or wrong-account grants.
4. Persist the new salted PIN hash without editing/deleting notes or clearing
   their lock flags. Revoke open note-unlock sessions; report storage failures
   without claiming success. Send a change notification without the PIN.
5. Handle offline, resend delay, delivery failure, expired links, link opened on
   another device, interrupted reset, unavailable account and wrong installation.
   Do not synchronize PIN state across devices until its sync policy is approved.

### Dependencies and limits

- Configure the existing Firebase identity integration or approve another identity
  provider, plus a trusted backend, HTTPS/deep-link destination and email sender.
- A Firebase account-password reset alone does not reset this independent local
  note PIN. A dedicated scoped recovery authorization is needed.
- Define retention, logging redaction, email-change authentication and abuse limits
  before deployment. Do not log reset tokens, PINs or full recovery links.
- Current note locks are access control, not database encryption. Before introducing
  encrypted backups/notes, design recovery of encryption keys as well as PINs;
  resetting an authentication credential cannot by itself recover an encryption key.
- Access to the verified mailbox is required. Mailbox-loss recovery belongs to the
  email/identity provider; no unauthenticated local bypass is proposed.

Security basis: [OWASP forgot-password guidance](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).

## Delivery sequence and approval gates

1. **Approved and implemented: Quiet paper.** The chosen direction uses the bottom
   editor rail, light/dark appearances and customizable paper styles.
2. **Theme foundation.** Persist appearance, migrate existing preference, fix
   semantic colors and contrast, verify switching under App Lock and note locks.
3. **Page realignment.** Library and editor first, then settings/security, dialogs,
   account/biometrics and startup. Preserve save, search, sorting and lock behavior.
4. **Recovery backend and integration.** Confirm provider/configuration, implement
   enrollment and server verification, then enable real recovery UI. Until then,
   recovery mockups remain explicitly planned and cannot claim to send emails.
5. **Release checks.** Update stable compiled preview; review actual screenshots
   in both themes and native biometric screens. Cloud backup/sync remains its own
   later milestone, informed by the recovery and encryption design.

## Acceptance coverage and deferred recovery checks

- System/light/dark switching and persistence across restart; system changes apply
  only in System mode; migration preserves the previous appearance.
- Every listed screen/dialog in both themes, all card colors, keyboard-open
  320x640 layout, larger phone/tablet/desktop widths and enlarged text.
- Keyboard navigation, screen-reader labels, contrast, focus/selection, disabled
  controls, save-failure retry, empty/search/error/loading/cooldown states.
- All existing Flutter and browser-startup regressions remain green. Theme changes
  preserve unsaved Quill Delta, explicit text colors and note/authentication state.
- Email ownership checks, current-PIN enrollment, tampered/replayed/expired tokens,
  resend limits, neutral responses, offline interruption, atomic reset failure,
  session invalidation and unchanged protected-note content/lock flags.

## Resolved approvals

- Quiet paper is the approved direction; amber remains the signature accent.
- Formatting stays in the bottom rail above the keyboard.
- Inline story is the approved image/audio layout, including uploads and recording.
