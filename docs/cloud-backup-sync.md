# Account-based cloud backup and sync

Implemented locally on 2026-11-17. The owner enabled R2 billing/subscription;
the private Standard bucket `jotit-private` and approved bucket-scoped backend
token are now created. Credentials are saved only in ignored `server/.env`.
A live 102-byte synthetic write/read integrity check passed. No real notes were
uploaded. The default Standard Firestore database is created in `europe-west3`
(Frankfurt), in production mode with client reads/writes denied. Backend
identity configuration and deployment are still pending.
The selected storage provider is **Cloudflare R2 Standard**, keeping Firebase
on **Spark** for authentication, App Check and Firestore sync metadata.
The app remains local-only until `JOTIT_CLOUD_URL` is configured and the user
explicitly connects **Settings → Backup & sync**.

## Behavior and account ownership

- The first connection links the existing local library to the reviewed verified
  Google/Firebase UID. It uploads saved notes and merges in that account's cloud
  library. Another device signs into the same account and connects to restore it.
- Text, rich-text Delta, timestamps, colors, paper, stickers/doodles embedded in
  Delta, image/audio bytes and locked flags are included. Unsaved drafts, PINs,
  PIN hashes, biometric preferences, OAuth credentials, recovery capabilities and
  appearance preferences are excluded.
- This is account-based access with HTTPS and provider-managed encryption at
  rest, **not end-to-end encryption**. A signed-in verified account with an
  approved App Check client can access its cloud notes, including locked notes.
  No recovery passphrase or approval from an existing device is required.
- Note PINs and App Lock are device-local. Restored locked notes remain locked;
  on a fresh installation the existing note-lock flow sets a new local shared
  PIN before opening them. Existing local PINs are kept. Mailbox/account recovery
  and note-PIN recovery are separate from cloud access.
- Signing out pauses transfers without deleting or hiding local notes. A library
  linked to UID A cannot be uploaded under UID B, even after sync is paused.
  Account switching/reassigning a library needs a future explicit migration flow.

## Sync, conflicts and restore

Hive stays the local source of saved notes. Saves remain available offline; the
last acknowledged cloud snapshot is kept as a three-way merge baseline. Local
edits and cloud acknowledgement use a shared write queue and a single Hive
envelope under `all`, so a failed local write cannot advance only the baseline.
Legacy lists remain readable and migrate on their next successful write. Do not
downgrade to APKs that only understand the old list format after migration.

The first implementation transfers whole-library snapshots (up to **2,000 notes
and 64 MiB of encoded JSON including base64 media**). It does not silently omit
oversize notes or attachments. Unchanged libraries check only head metadata.
Saved changes are debounced for three seconds. Remote changes are checked once
per minute while the app is open; this is not background OS scheduling or live
collaborative editing. Network work waits while the editor is open, the app is
locked/backgrounded, a save is active, or the local library failed to load.

Server revisions and transactional compare-and-set prevent stale devices from
overwriting newer cloud state. Device timestamps do not decide winners. Separate
note edits merge; simultaneous edits preserve a deterministic conflict copy.
Edit/delete conflicts preserve the edited version. An unchanged device accepts
acknowledged deletions. A locally changed library or switched account during a
request cannot be overwritten by the late result. Failed network/save operations
can be retried; previously generated conflict copies have deterministic IDs.

Each successful changed snapshot becomes a backup. **The newest 20 revisions**
are browsable. Restore adds recovered copies and preserves current notes; it
does not rewind or replace the library. Repeating the same restore does not add
another identical set. Restored copies can then sync to the other devices.
An empty library does not need an initial empty backup.

## Server configuration and deployment

The standalone Node service uses `firebase-admin` and Cloudflare's supported
AWS S3 SDK (`@aws-sdk/client-s3`); no additional Flutter SDK
dependencies or API/service-account secrets are embedded in the app. Set:

- `FIREBASE_PROJECT_ID`: the existing project.
- Application Default Credentials for a dedicated server identity with access
  only to the required Firestore records and Firebase
  Auth user reads needed for ID-token revocation checks.
- `R2_ACCOUNT_ID`: the Cloudflare account's 32-character account ID.
- `R2_BUCKET`: a dedicated private R2 Standard bucket, e.g. `jotit-private`.
- `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`: server-only S3 credentials from
  an R2 Object Read & Write token restricted to this bucket. Keep them in ignored
  local `.env` or host-managed secrets; never in Flutter, Git or chat.
- `CLOUD_APP_IDS`: approved Firebase App IDs, not Android package names.
- `CLOUD_ALLOWED_ORIGINS`: optional explicit web origins, comma-separated.
- `CLOUD_PORT`: defaults to 8789; `HOST` defaults to loopback. Containers use
  `0.0.0.0` behind an HTTPS ingress.

Run `npm run start:cloud` from `server`, or build `server/Dockerfile.cloud` with
the server directory as its build context. `GET /health` reports readiness;
authenticated, attested POST actions are `/v1/cloud/{history,read,write}`.
Build Flutter with:

```sh
flutter build apk --release --dart-define=JOTIT_CLOUD_URL=https://your-cloud-host/v1/cloud
```

Choose an HTTPS host/proxy that supports requests and responses above 64 MiB and
appropriate memory for concurrent snapshot serialization. Some managed hosting
products have smaller request limits; verify that before choosing one, or lower
the matched client/server limit and clearly disclose it. Impose connection/IP
limits at ingress, bound concurrency and set operational storage/transfer budgets.
Never log request/response bodies, Authorization or App Check headers. The service
limits each UID to 360 charged actions and 512 MiB of snapshot transfers per hour;
reads/writes also charge their transfer bytes. Limits are durable in Firestore.

Firestore stores only UID-hashed head/history/quota records in
`jotitCloudLibraries`. Private immutable JSON objects live under
`jotit-note-cloud/{sha256(uid)}/{snapshotDigest}.json`. Writes upload before the
Firestore transaction; failed CAS/uploads cannot advance the head. The server
validates note schema, content hashes and bounded request sizes. Firebase ID
tokens are checked for revocation and App Check IDs are allowlisted.

`cloud.firestore.rules` is a deny-all example for a dedicated server-only
database. Review/merge shared rules instead of replacing existing application
rules. Keep R2's public development URL and custom-domain public access disabled.
The backend uses a fixed account-scoped R2 endpoint and conditional S3 writes;
no R2 credentials or publicly signed URLs are issued to the app. Firebase Admin
access uses IAM and bypasses client security rules.

**Firebase stays on Spark.** Firebase Cloud Storage is not used. Cloudflare R2
Standard currently includes 10 GB-month storage, one million Class A operations
and ten million Class B operations per month, with free direct R2 egress. Above
the included allowances, usage is billable. Enabling R2 requires its subscription
checkout; the owner completed this for R2. Firebase billing remains unchanged.
Firestore's Spark quotas still apply to sync metadata. Whole-library
snapshots can use substantial bandwidth/storage for media-heavy libraries;
incremental attachment transfer is a future optimization.

Only the latest 20 revisions are exposed by the app. Unreferenced immutable
objects (including failed-CAS uploads) are not automatically deleted. Define an
operator retention/deletion process and account-data deletion workflow before
public rollout. Do not apply a blanket object-age lifecycle rule: it can delete
an old object still referenced by a current head or retained backup. Safe object
collection must account for active writes and retained references. Account
deletion and self-service cloud purge are not implemented in this milestone.

## Validation and remaining live checks

Local verification (2026-11-17): full serial Flutter suite **288 passed**;
the final restore/navigation changes passed the focused **12-test** cloud run;
project-wide analysis is clean; all **43 backend tests** passed, including the
private R2 adapter. The arm64 release APK was rebuilt and signature-verified
with the existing Android Debug certificate for local testing. It has no live
cloud endpoint configured. A live synthetic R2 transfer passed; authenticated
end-to-end backup/restore and two physical devices have not been verified.

Synthetic tests cover serialization, three-way conflicts, delete/edit handling,
two-device convergence, opt-in/account isolation, sign-out during requests,
failed local acknowledgement, offline retry, restore idempotency, Hive reopening,
metadata-only polling, App Check/auth/CORS and narrow enlarged UI layout.

Before enabling a distributed build: deploy the private service/resources,
verify a real backup and fresh-device restore with synthetic notes/media, test
offline concurrent edits and interrupted writes on two devices, exercise sign-out
and wrong-account attempts, verify local PIN setup after restore, inspect budgets
and monitoring, and establish server-data retention/deletion operations.

To activate: provision private Firestore metadata access and deploy the Node
service to an HTTPS host. R2 bucket/token setup and local configuration are done.
Then build with its endpoint and test synthetic notes on two devices before
connecting the real library. The existing Dockerfile is deployable to a Node
container host. Render was selected for deployment preparation; see
[Render deployment instructions](render-cloud-deployment.md) and root
`render.yaml`. No Render service or hosting URL has been created.

References: [R2 pricing](https://developers.cloudflare.com/r2/pricing/),
[R2 setup](https://developers.cloudflare.com/r2/get-started/),
[R2 SDK configuration](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-js-v3/),
[Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions),
[Firestore document limits](https://firebase.google.com/docs/firestore/quotas),
[R2 conditional operations](https://developers.cloudflare.com/r2/api/s3/conditional-operations/).
