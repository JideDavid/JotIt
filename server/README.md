# Gemini note assistance

The native app now defaults to Firebase AI Logic. See [Firebase setup](../docs/firebase-ai-setup.md). This Node service is an optional development/hosted alternative used only when `JOTIT_AI_URL` is supplied. No Gemini key is embedded in the Firebase build.

The Flutter editor calls this authenticated backend; the Gemini API key never belongs in a Flutter build, browser bundle, repository, or note. The backend uses the Gemini REST API and returns a bounded plan of native Quill edits. Stickers and doodles use the same catalog and persistence as manually inserted ones.

## Run locally

Requires Node 22 or newer and an existing Firebase project with Google sign-in enabled for the Android app.

```powershell
cd D:\Apps\JotIt\server
npm ci --ignore-scripts
Copy-Item .env.example .env # Only if .env does not already exist
```

Edit the ignored `.env` file locally. Set `GEMINI_API_KEY` and `FIREBASE_PROJECT_ID` (the same project as `android/app/google-services.json`). `GEMINI_MODEL` is configurable; the checked default is `gemini-3.5-flash-lite`. Do not share `.env` or put its key in `--dart-define`.

```powershell
npm start
```

`GET http://127.0.0.1:8787/health` returns readiness without secrets. `POST /v1/assist` requires a valid Firebase ID token; use the app's existing Google account sign-in first. Local guest notes continue to work without AI. There is no authentication bypass in development.

For an Android emulator:

```powershell
flutter run --dart-define=JOTIT_AI_URL=http://10.0.2.2:8787/v1/assist
```

For a USB-connected Android phone with USB debugging authorized:

```powershell
adb reverse tcp:8787 tcp:8787
flutter run --dart-define=JOTIT_AI_URL=http://127.0.0.1:8787/v1/assist
```

Keep the computer/backend running. The reverse connection must be renewed after reconnecting the phone. HTTP localhost is supported only by debug builds; production requires HTTPS. The ordinary browser preview uses local-only account stubs and cannot obtain Firebase tokens for live AI.

The supplied local test APK targets ARM64 Android phones. To rebuild that version:

```powershell
flutter build apk --debug --target-platform android-arm64 --dart-define=JOTIT_AI_URL=http://127.0.0.1:8787/v1/assist
```

After building the debug APK and starting the backend, the repository helper can connect and install on exactly one authorized USB phone, preserving existing app data:

```powershell
cd D:\Apps\JotIt
.\scripts\connect_local_ai.ps1 -Adb C:\dev\android-sdk\platform-tools\adb.exe
```

## Hosted build

Deploy this Node service behind HTTPS on a host of your choice, supply the same server environment secrets, set `HOST=0.0.0.0` if the host requires it, and set `ALLOWED_ORIGINS` to exact approved web origins if serving a web app. Native Android requests have no Origin header and still require Firebase authentication. Do not expose a development server or its `.env` files as static content.

```powershell
flutter build apk --release --dart-define=JOTIT_AI_URL=https://YOUR-HOST/v1/assist
```

An app built without `JOTIT_AI_URL` clearly reports that Gemini is not connected. The `/v1/assist` suffix is required. A deployed endpoint is intentionally not invented or bundled by default.

The backend can also run from its `server/Dockerfile` (use `server` as the Docker build context). The image includes only runtime code and dependencies; `.env`, keys, tests and notes are excluded. Supply `GEMINI_API_KEY` and `FIREBASE_PROJECT_ID` through the host's secret/environment settings. The container binds to `0.0.0.0` and honors the host's `PORT`. Use one instance while the rate limiter is process-local. A native-only deployment can leave `ALLOWED_ORIGINS` empty. Configure `/health` as the readiness endpoint and allow at least 65 seconds per request. `npm start` also works with host-injected environment variables when no `.env` file exists.

After deployment, build using the checked helper:

```powershell
.\scripts\build_release_ai.ps1 -AiUrl https://YOUR-HOST/v1/assist
```

The helper verifies HTTPS, protocol 2 readiness and rejection of unauthenticated requests before building. It embeds only the backend URL. After installing, sign in and test a synthetic note through the full proposal/Apply flow. These preflight checks do not themselves verify Gemini quota or a signed-in generation.

## Editing and data flow

- Format, Refine and Create operate on selected text, the whole note, appending at its end, or a new note.
- A request sends the chosen text scope, its existing formatting and link attributes, the prompt, the current appearance, and catalog metadata including actual style properties. Media bytes, embed IDs and other notes stay local. Existing media/stickers appear as object markers and are preserved during rewrites.
- Proposals are separate drafts. Original/proposed previews and follow-up prompts do not edit the note. Apply checks that the note is still the same document and revision, then creates one undo/redo transaction. Save new note persists independently of the current draft.
- Protocol 2 asks Gemini for paragraph IDs and exact unique quotes, never character offsets. The server resolves anchors and requires review coverage for the entire supplied scope. Up to 200 operations support complete longer notes. Inline emphasis is separate from paragraph roles; a body reset can clear excessive formatting before focused highlights are applied.
- The client and server validate ranges, schema, catalogs, text sizes, colors and output types. They reject overlapping text edits, split words/UTF-16 characters, mid-sentence decoration insertion, rewritten links and attempted media deletion. Invalid, blocked, truncated or timed-out responses never partially apply.
- Default decoration limits allow up to four new objects, two fonts, three accents and short highlights. An explicitly expressive request can relax overall density. Readable text/background pairs are checked against the actual preview theme, including inherited highlights.
- The preview's Details report displays computed operation counts, the design plan and separate content warnings. Format preserves wording; Refine/Create may rewrite anchored text. Claims about missing sources or uncertain outcomes should become review warnings rather than invented facts. Existing saved notes are not automatically reformatted.
- Requests require Firebase authentication and have per-user limits, a small global concurrency cap and size/time limits. Rate counters are process-local; use a shared limiter before scaling to multiple replicas or offering public access at scale.
- Note content, prompts, tokens and Gemini keys are not logged by this service. Google's free-tier API data policy still applies: [pricing and data-use table](https://ai.google.dev/gemini-api/docs/pricing). Users see this before generating.

## Verify

```powershell
npm test
node --env-file=.env check-gemini.mjs
node --env-file=.env check-semantic.mjs
```

The smoke check explicitly calls Gemini with a synthetic checklist request and prints only status and native element types. `--save` saves its synthetic plan to ignored `.gemini-smoke.json`. It does not use the user's notes.

The semantic smoke check uses a synthetic fourteen-section roadmap, checks all fourteen headings, and saves a reproducible synthetic fixture for the Flutter compiler test. It never reads personal notes. The backend health response exposes `protocolVersion: 2`; new clients reject a legacy response for a structured request, rather than silently returning to model-counted offsets.

The schema sent to Gemini omits nested numeric/array cardinality constraints because the tested model rejects that more complex schema. The backend and client still enforce all limits when validating the actual response.

To add catalog formats later, add their unique visual definition and renderer to `StickerCatalog`. Color remains an instance property. The live catalog is sent with each AI request; no independent list of design names is hard-coded into the backend.
