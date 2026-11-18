# Render deployment for note backup and sync

Prepared on 2026-11-17; source published on 2026-11-18 to
`codex/cloud-backup-sync` (implementation commit `ec5b085`). No Render service
has been created or deployed.
The root `render.yaml` defines one Docker web service, using the existing
`server/Dockerfile.cloud`. It does not deploy Gemini or PIN recovery.

## Resources already verified

- Firebase project: `jotit-ab937`, still on Spark.
- Default Firestore database created in `europe-west3` (Frankfurt), Standard
  edition, production mode with client reads/writes denied.
- R2: private Standard bucket `jotit-private`; public access disabled.
- Bucket-scoped Object Read & Write credentials are in ignored `server/.env`.
- A 102-byte synthetic object passed the live R2 write/read integrity check.
  No real notes were uploaded. This test object remains in the bucket.

## Before deployment

1. The owner account `zaleltechltd@gmail.com` has the necessary console access.
   An initial permissions message disappeared after refreshing the console.
2. The default Firestore database is provisioned in Standard edition,
   production mode in Frankfurt. No metadata collections or real notes have
   been written. Keep its deny-client rules for this server-only database.
3. Create a dedicated backend service identity. Grant only Firestore data
   access needed for `jotitCloudLibraries` operations and Firebase Auth user
   reads for revocation checks. Do not grant Owner or Editor. IAM database
   access is broader than client rules; isolate the identity to this project.
4. Create its service-account key only after approval. Keep it out of Git,
   chat and the APK. Render needs the JSON as a secret file named
   `firebase-cloud-service-account.json`; ADC reads `/etc/secrets/...`.
5. The implementation and Blueprint are pushed to `codex/cloud-backup-sync`.
   Select this branch when creating the Render Blueprint; `main` does not yet
   contain these changes.

## Render setup

Connect the JotIt GitHub repository, select `codex/cloud-backup-sync`, and create
a Blueprint from `render.yaml`. Render Google sign-in reported no existing
account for `zaleltechltd@gmail.com`; account creation/terms acceptance is pending
owner approval, along with backend IAM/key creation and secret transfer.
Review the single Free web service before deploying. Auto-deploy is disabled
so future repository pushes do not automatically release this backend.

Provide only `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and `CLOUD_APP_IDS` when
prompted. Copy the two R2 values from the ignored local configuration directly
to Render's secret environment fields after approving that credential transfer.
Use Firebase App IDs (Android and optionally the registered testing web app),
not the Android package name. Do not bulk-upload `server/.env`: it also contains
unrelated service credentials. Add the Firebase secret file before expecting a
working deployment; a service started without it is not ready for sync.

For browser testing only, add `CLOUD_ALLOWED_ORIGINS` with the exact local
testing origin. Native Android requests do not require this variable. Keep R2
public access disabled; the app accesses objects through the authenticated
backend, never through a public bucket URL.

## Activation and verification

Check `https://<assigned-service>.onrender.com/health` for the protocol response.
This route confirms process liveness, not Firebase/R2 permission readiness.
Confirm unauthenticated cloud requests are rejected, then run an authenticated
synthetic backup, read and restore with Firebase App Check before real notes.

Build the app with:

```powershell
flutter build apk --release --target-platform android-arm64 --dart-define=JOTIT_CLOUD_URL=https://<assigned-service>.onrender.com/v1/cloud
```

Connect Backup & sync explicitly on two test devices and verify concurrent
edits, interrupted uploads, offline retry, locked-note PIN setup and account
isolation. Define retention and account-data deletion before public rollout.

## Free-instance limits

Render Free spins down after 15 idle minutes and waking can take about a
minute. The app has a 90-second request timeout; the first sync after idle may
need retrying. Free instances are for testing, not production availability.
Data persists in R2/Firestore, independent of Render's ephemeral filesystem.
Review Render bandwidth/build limits and R2/Firestore quotas before rollout.

References: [Blueprint specification](https://render.com/docs/blueprint-spec),
[secret files](https://render.com/docs/configure-environment-variables),
[Free instance limits](https://render.com/docs/free).
