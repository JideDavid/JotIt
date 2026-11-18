# Shared note PIN recovery

Implemented locally on 2026-11-17. Live sending is **not configured or deployed**. The normal release has no `JOTIT_RECOVERY_URL`, so the recovery page explains that the service is unavailable and sends no email. App Lock recovery and cloud sync are separate features.

## User flow

1. Set a shared note PIN, sign in with a verified Google account, then open Settings → Recovery email.
2. Link recovery using the **current note PIN**. Enrollment requires recent Firebase authentication (within five minutes); sign out and back in if requested. Enrollment is bound to the Firebase UID and this local installation, not just an email address. A different signed-in account cannot take over enrollment.
3. If the note PIN is forgotten, request a recovery email. Paste its full link into the app, choose and confirm a new note PIN, then Reset note PIN. The link lasts 15 minutes, can authorize only one reset, and is unusable from another installation/account.
4. A successful reset keeps protected-note flags and content intact, revokes open note-unlock sessions, and leaves App Lock independent. A notification email reports that recovery was authorized without containing PINs or note content.
5. Unlink recovery using the current note PIN. Outstanding links are invalidated. An unenrolled forgotten PIN has no recovery path; account sign-in alone does not bypass it.

If the verified email changes on the same Google/Firebase account, Update recovery email requires the current note PIN and recent sign-in again. It invalidates outstanding old links. Moving enrollment to a different Firebase UID is not supported.

The email link opens an inert HTTPS page with instructions. This first implementation uses copy/paste back into the app; automatic Android/iOS deep-link handling is not implemented. Email scanners or a GET cannot consume the token. The secret is in the URL fragment, not the query/path sent to the server. The app accepts only links from its configured recovery origin and `/recover` path.

## Backend configuration

The recovery server is independent of Gemini. It uses existing `firebase-admin` dependencies, Firestore transactions, Firebase ID-token revocation checks and verified App Check tokens. A Gemini key is not required.

- `FIREBASE_PROJECT_ID`: existing Firebase project.
- Application Default Credentials for a dedicated server identity with access to its recovery Firestore database and the Firebase Auth user-read access needed for token-revocation checks. Never put service-account keys in Flutter, assets, the repository or browser configuration.
- `RECOVERY_APP_IDS`: comma-separated Firebase **App IDs**, not Android package names. Allow only intended JotIt registrations.
- `RECOVERY_RESET_URL`: fixed `https://your-recovery-host/recover` URL, without query/fragment.
- `RECOVERY_EMAIL_API_KEY` and `RECOVERY_EMAIL_FROM`: server-only credentials and a provider-verified sender. The initial adapter is Resend; `sendMail` is injected so another provider can be added without changing the reset protocol.
- `RECOVERY_PORT` defaults to 8788. `HOST` defaults to loopback for local use; expose it only behind a configured HTTPS service. `RECOVERY_ALLOWED_ORIGINS` is optional for specifically approved web clients.

```sh
cd server
npm run start:recovery
```

For a container, build `server/Dockerfile.recovery` using the server directory as the context. Configure credentials as host-managed secrets. Its runtime contains no Gemini handler or key. Health: `GET /health`; actions: authenticated, attested POSTs under `/v1/recovery/{enroll,status,request,redeem,disable}`. Request bodies are bounded; no endpoint logs credentials or recovery-link contents. Hosting/proxy access logs must redact Authorization, App Check headers and all request bodies.

Use a server-only Firestore database. The provided `recovery.firestore.rules` denies all direct client access for a dedicated database; review existing database rules before applying it. A more permissive overlapping allow rule must not expose `jotitNotePinRecovery`. Do not deploy rules blindly over unrelated applications. Enrollments store UID/email, installation capability **hash**, epoch and hashed expiring challenge. No PIN, PIN hash or note content reaches the backend; only a one-way fingerprint of the newly chosen encoded hash binds an authorization receipt.

The service limits a Firebase UID to 30 actions/hour across installations, recovery emails to one/minute/installation, and invalid token attempts to five/challenge. Deployment should also impose connection/IP limits before Firebase verification. Persist quota state in Firestore across restarts. Disabled enrollment records remain as revocation tombstones; define an operator cleanup/retention policy before live rollout. No cloud deletion or retention job has been deployed.

Build the normal app with the configured HTTPS endpoint:

```sh
flutter build apk --release --dart-define=JOTIT_RECOVERY_URL=https://your-recovery-host/v1/recovery
```

The endpoint origin must match `RECOVERY_RESET_URL`. Keep existing signing/App Check configuration. Changing a PIN does not encrypt the local Hive database or recover encryption keys; existing note locks are in-app access controls.

## Interrupted reset safety

The existing scalar PIN hash remains readable. Enrollment wraps it in a metadata envelope under the same Hive key. A reset persists a pending encoded hash, operation ID, token fingerprint and next epoch **before** redeeming the link. The server consumes the token and stores a receipt transactionally. Only a matching receipt can commit the new PIN and recovery epoch in a single Hive write. The same authorized operation can be retried idempotently after a failed response or local save; it cannot choose a different PIN/hash using the consumed link. A newly requested link reconciles the server epoch and supersedes an unfinished local attempt without changing the local PIN.

Account changes, App Lock, disposal, changed local bindings and malformed server receipts fail closed. Enrollment verification uses the note view model's existing attempt throttling. Successful recovery does not automatically unlock notes. Existing unsaved drafts stay in memory and are covered by the lock gate.

After enrollment, use builds that support the metadata envelope; older APKs only understand scalar PIN records. Do not uninstall the app to switch builds: local note storage belongs to the installation.

## Validation and activation

Local tests use synthetic accounts, tokens and PINs. They cover verified/recent enrollment, wrong account/device, expired and replayed tokens, concurrency, sender failure, HTTP App Check/auth, failed local writes, exact-operation retries, sign-out during reset, native PIN record reopening, note-session revocation, and narrow keyboard-open form layout.

Latest local checks (2026-11-17): all 13 recovery backend tests and 25 focused Flutter recovery, AI-request and note-lock tests passed. Analysis of the recovery service, page and tests reported no issues. These checks do not establish real email delivery or phone behavior.

```sh
node --test server/note-pin-recovery.test.mjs server/recovery-server.test.mjs
flutter test test/note_pin_recovery_test.dart test/note_lock_test.dart test/hive_local_storage_service_test.dart
```

No real email, cloud database write, domain registration, billing change or deployment has been performed. Activation needs an approved host/database configuration and a verified email sender. Before enabling it in a distributed release, exercise a real enrollment, delivered email, expiry, replay rejection, interrupted save/retry, account switch and reopened protected note on the target phone.

Implementation references: [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [Resend email API](https://resend.com/docs/api-reference/emails/send-email).
