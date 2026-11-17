# Inline media and PIN interaction

The user approved the Inline story attachment design: media is inserted at the
cursor between paragraphs, while the formatting rail stays at the bottom.

The formatting rail is one horizontally scrolling row above the keyboard. Touch
and mouse dragging, trackpad scrolling and previous/next arrow buttons expose
inline and paragraph tools directly. Scrolling the rail preserves the note's
selection and takes no extra text rows.

Font family opens a preview picker with ten bundled Google Fonts. The selection
is unchanged until Apply font; Cancel leaves the draft intact. Family attributes
use Quill's existing `font` attribute, so mixed typefaces, undo/redo, clear
formatting and save/reopen use the same rich-text persistence. Static TrueType
faces are bundled for offline use; supported bold/italic variants have explicit
font registrations. Font licenses ship in the app's license registry. Upstream
URLs and SHA-256 hashes are recorded in `assets/fonts/SOURCES.json`; refresh with
`scripts/bundle_note_fonts.ps1`.

## Current implementation

- The paperclip opens image upload, audio-file upload and voice recording.
- Images can be enlarged; audio includes playback and seeking. Removal asks for
  confirmation, is undoable in the editor session, and persists on Save. Original
  device files are never deleted.
- Custom embeds explicitly occupy their own paragraphs in one undoable Delta.
  Consecutive imports keep the following sentence intact; insertion within styled
  text preserves both halves and their paragraph attributes.
- Each attachment has a drag handle. Drag it up or down to a line in the note;
  a drop marker previews its position, and holding near the editor edges scrolls
  longer notes. Moving works with touch and mouse, preserves text formatting and
  media bytes, is one undo/redo action, and persists on Save. Dropping outside
  the editor leaves the attachment in place.
- Attachment bytes are copied into optional Hive field 8 alongside the note's
  Quill Delta. Old notes need no destructive migration. Media, text, style and
  lock state use the same persist-first save and failure/draft protections.
- Limits: 5 MB per file, 20 MB and 12 attachments per note; images under 40 MP.
  Images: PNG/JPEG/GIF/WebP. Audio: MP3/WAV/M4A/AAC/OGG/WebM/FLAC, subject to the
  device's codec support. Unsupported files show an error without clearing notes.
- Voice notes request microphone permission only on Start recording. Capture is
  mono PCM as WAV, up to two minutes. Hidden/paused app state or a privacy lock
  stops playback and recording. Captured audio remains for review after unlock;
  a file chosen while locked waits for explicit attachment after unlock.
- Media remains local and is not encrypted by the PIN. Clearing browser storage
  or uninstalling can remove it; cloud backup is not enabled. Storage/quota
  failures retain the draft for retry.

## Platform validation

Browser recording requires HTTPS or localhost. Physical microphone permission,
actual-device codecs, and native platform builds still require device testing.
Linux recording needs the record plugin's system audio utilities. On Windows,
Flutter native-plugin builds need symlink support (Developer Mode); no system
settings are changed automatically. Browser builds can use resolved dependencies
with `--no-pub` when the native symlink post-step is unavailable.

Local browser verification includes PNG import/enlargement, WAV upload, playback,
pause, keyboard seek, save/reload of both file types, custom tint and favorite
persistence. The automated file chooser needs normalized forward-slash fixture
paths on this host. Microphone capture is covered with a fake backend but has not
been exercised against the user's real microphone.

Run `python scripts/serve_preview.py --port 7357` after building the preview.
This loopback-only server disables caching. The inline Flutter bootstrap uses a
fresh entrypoint URL on localhost so reloads do not silently show an older build.
Neither cache control nor retry clears Hive notes or PIN settings.
On Windows, `scripts/build_preview.ps1 -Flutter C:\dev\flutter\bin\flutter.bat -NoPub`
rebuilds the preview with refreshed web-plugin registration when dependencies are
already resolved. This avoids stale build entrypoints after dependency changes;
it removes only generated entrypoint stamps, never notes or PIN settings.

## PIN behavior

App unlock and the dedicated note-unlock screen check the fourth digit
automatically, without a separate Unlock button. Incomplete input is not
an authentication attempt; pending checks reject duplicate submissions. Failed
checks clear input and preserve the existing retry/cooldown rules. PIN setup,
deletion and removing protection still require explicit confirmation.

## Library cards

Unlocked cards echo the note's paper pattern, spacing and strength at a subdued
intensity over their selected tint. Locked cards expose neither paper style,
color, attachment details, title nor text.

## Custom card colors

Note actions > Note card color now offers the original nine presets, a hue and
saturation wheel, brightness and precise sliders, and a six-digit hex field.
The preview shows the subdued library tint rather than replacing the writing
paper or authored text colors. Custom values use opaque ARGB integers in the
existing color field; old preset indices and Hive fields remain unchanged.
Both appearances derive readable surfaces and markers from the chosen color.

Up to 24 favorite colors are stored independently on this device. Adding or
removing a favorite is persist-first, with retryable failures and no note edits.
Cancel leaves the note's tint unchanged; Apply then Save keeps its new tint.
Locked cards remain neutral and reveal neither preset nor custom colors.

## Follow-up

Verified-email shared-PIN recovery and cloud sync remain planned, not enabled.
