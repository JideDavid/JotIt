# Firebase AI Logic for JotIt

The default native app uses the official `firebase_ai` SDK with Gemini Developer API. It does not need `JOTIT_AI_URL`, a running computer, a custom backend, or a Gemini key in the APK. Internet and the existing Google account sign-in are required. The older backend remains available only when an explicit `JOTIT_AI_URL` is supplied for development.

## Console setup

1. Open Firebase project `jotit-ab937`, AI Services > AI Logic. Complete Get started using Gemini Developer API.
2. Open Security > App Check > Apps. Register `com.zaleltech.jot_it` using Play Integrity and the signing certificate SHA-256. The current local release still uses the existing debug signing certificate, **not a production signing key**:

   `A1:B2:0E:A6:26:CC:06:D1:52:16:53:A7:A3:18:05:7E:DE:BF:0A:C1:1B:9A:47:32:31:33:65:44:BC:F5:83:E2`

3. For APKs distributed exclusively outside Google Play, configure PLAY_RECOGNIZED and LICENSED as not required, and require Device integrity. Follow the Play Integrity setup flow, including linking the same Cloud project where required. Before publishing on Play, use a proper release signing configuration, register the Play app-signing fingerprint and review the distribution settings.
4. Under App Check > APIs, ensure Firebase AI Logic is enforced. Register before enforcing if the setup has not already enforced it.
5. For debug builds, run the app, obtain the device's App Check debug token from local logcat, and register it under App Check > Apps > Manage debug tokens. Keep debug tokens private. Release builds always use Play Integrity; there is no release debug-provider switch.

## Build and verify

```powershell
flutter build apk --release
```

No secret build arguments are needed. The default model is `gemini-3.5-flash-lite`; change the public model name with `--dart-define=JOTIT_GEMINI_MODEL=...` only when supported by Firebase AI Logic and the project's quota/tier.

Install, sign in, and use a synthetic note. Generate formatting and a checklist/sticker request, review the proposal, then Apply and Undo. Confirm App Check verified traffic in the console. Compilation and mocked tests do not establish that console registration, model access or free quota are ready.

The model chooses exact quotes and paragraph IDs. The app resolves offsets and validates scope, complete coverage, decorations, native catalog formats, links and media before previewing. No note/prompt/token logging is added. Only the selected note scope is sent to Gemini. Free-tier data use and quota still apply. Client-side limits cannot replace Firebase/project-side abuse protections.

If a completed proposal fails validation, the client requests one complete correction with bounded validation feedback, within the original 60-second time budget. It never applies the invalid partial plan. Palette violations get specific feedback about the three-accent limit. Network, authentication and quota failures are not automatically retried.

Whole-paragraph heading/quote presets may supply inline typography alongside an explicit matching semantic paragraph role. The editor strips the preset's block attributes, so hierarchy still comes exclusively from the role. Phrase targets, conflicting roles and absent roles are rejected with specific correction guidance. Saved phone responses that previously failed on `amber-heading` now resolve locally; live generation on the updated APK still needs device verification.

Create on a completely empty whole/new note accepts a zero-length replacement of p0 as an insertion. This normalization never applies to Format, Refine, selected text, append, or blank lines within existing content. The prompt explicitly asks for insertions on an empty canvas, and correction feedback distinguishes empty targets from Format restrictions. The four captured failed Create proposals now validate and render their generated native blocks in offline replay.

## Local browser test

The Firebase web client is named `JotIt web testing`. Local public Firebase configuration is stored in ignored `.dart_tool/firebase-web-test.json`. It contains the web registration values and `JOTIT_WEB_AI_TEST=true`, not a Gemini key or App Check debug token. The revocable browser token is registered under App Check > JotIt web testing > Manage debug tokens as `Local JotIt browser test`.

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7358 --dart-define-from-file=.dart_tool/firebase-web-test.json
```

Open `http://localhost:7358/`, sign in with Google, and use a synthetic note. The ordinary preview on port 7357 still uses sample accounts. The local debug provider is restricted in code to debug mode and loopback hosts; Android releases always use Play Integrity. Production web needs a real App Check reCAPTCHA site key and registered domain using `JOTIT_APP_CHECK_WEB_SITE_KEY`. Do not add localhost to production reCAPTCHA allowed domains. Revoke the local debug token in the console when browser testing is finished. Google sign-in has so far failed with `network-request-failed` in the Codex in-app browser; live browser generation is not yet verified.

Official guides: [AI Logic](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter), [App Check for Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers), [Play Integrity settings](https://firebase.google.com/docs/app-check/android/play-integrity-provider).
