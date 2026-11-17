# Optional account sign-in

Phase 1 adds Google account identity without making an account a requirement for
local notes. Cloud backup, cross-device sync, email/PIN recovery and account
deletion are not implemented in this phase.

## Behavior

- Startup restores the Firebase SDK's existing session and subscribes to user
  changes. It never forces a sign-in screen before opening local notes.
- Missing Firebase initialization/configuration leaves a usable local-only app
  with an explanation on the Account page. Unsupported desktop platforms do not
  attempt Google authentication.
- Settings > Account shows the connected email and its SDK-reported verification
  state. A verified Google email is **not** enrollment in PIN recovery.
- Sign-in is explicit. Cancellation is a neutral notice; connection, blocked
  popup and configuration errors are retryable and do not alter notes or PINs.
- Sign-out requires confirmation, ends the Firebase session first, then attempts
  Google-provider cleanup. Provider cleanup failure cannot leave Firebase signed
  in. This is local sign-out, not revocation of the user's Google grant.
- Notes, attachments, appearance, favorites, App Lock and the shared note PIN
  remain on the device after sign-in and sign-out. Local notes are not partitioned
  by account, claimed by an account, uploaded, or deleted. The confirmation and
  Account page disclose this explicitly for shared-device users.
- Account operations do not navigate on completion, unlock App Lock, reset a note
  PIN, or modify storage. Returning to notes reuses the existing library route
  instead of stacking another library over Settings.
- Firebase owns token persistence; JotIt does not copy OAuth credentials or tokens
  into Hive. Raw authentication errors and tokens are not logged or shown in UI.
- The sample web preview intentionally has no real account access and uses its
  existing separate local boxes. It must not be used to validate a live sign-in.

## Android Firebase setup

The existing project is `jotit-ab937`; the Android package is
`com.zaleltech.jot_it`. Do not create a second project or a service-account key.

1. In Firebase Authentication > Sign-in method, enable Google and choose the
   project's support email. This requires the project owner's approval.
2. In Project settings > General > Your apps, select the Android app and register
   the SHA-1 and SHA-256 fingerprints of the certificate actually signing the APK.
   `android/app/build.gradle.kts` currently uses the local debug certificate even
   for release-mode APKs. Re-register if signing changes; never distribute a
   signing private key or keystore.
3. Download a fresh `google-services.json` after enabling the provider and adding
   fingerprints. Replace `android/app/google-services.json` with the matching
   configuration containing OAuth clients. This file is ignored by Git.
4. Rebuild the APK from `lib/main.dart`, not the sample `lib/preview.dart`:

   ```powershell
   C:\dev\flutter\bin\flutter.bat build apk --release --no-pub
   ```

5. Install without clearing application data. Verify real Google sign-in,
   cancellation, process restart, offline reopening, sign-out and retry on an
   Android device. Check the displayed account email before connecting real data.

The release Android manifest includes INTERNET permission; authentication must
not depend on the debug-only manifest.

No Firestore database, Storage bucket, database rules, billing upgrade, service
account or notes upload is needed for this phase. Do not enable public data rules
to fix sign-in errors.

### Setup performed on 2026-11-14

With the project owner's confirmation, Google was enabled, the public-facing
name set to JotIt, and `zaleltechltd@gmail.com` selected as the support email.
Both fingerprints were saved and verified in Firebase against the actual APK:

- SHA-1: `7C:EA:11:07:56:94:9A:4E:31:0D:01:2D:6C:B3:DA:48:AF:D1:6F:69`
- SHA-256: `A1:B2:0E:A6:26:CC:06:D1:52:16:53:A7:A3:18:05:7E:DE:BF:0A:C1:1B:9A:47:32:31:33:65:44:BC:F5:83:E2`

The owner supplied the fresh configuration after browser downloads timed out.
It was validated for the project ID, Android package, Android and web OAuth
clients, and the APK's SHA-1 certificate before replacing the ignored
`android/app/google-services.json`. A copy of the previous configuration is kept
under the ignored `.dart_tool` directory. Real-device login still needs checking.

The release APK rebuilt successfully from `lib/main.dart`. Inspection verified
the expected web OAuth client in packaged resources, INTERNET permission, Android
package/version, and the same signing certificate registered above. The artifact
is `build/app/outputs/flutter-apk/app-release.apk` (73.1 MiB, version 1.0.0+1,
Android 7/API 24 or newer; ARM32, ARM64 and x86-64). SHA-256:
`3A8E9E7F891B313A84195419AE166BD1506303CF5C527211D36D599A63B6369F`.

The full serial suite passed 190 tests, and both subsequently added offline and
late-result regressions pass in the 27-test focused account/service run. Static
analysis reports only the existing unrelated unused import in `tab_button.dart`.

## Other platforms

The service uses Firebase popup sign-in on configured web builds; the default
entrypoint currently has no generated web Firebase options. Supply the project's
correct `FirebaseOptions` to `GoogleAuthService.initialize(options: ...)` before
claiming a production web build supports live sign-in. Configure authorized
domains in Firebase and test browser popup restrictions separately.

Apple targets require their own Firebase application configuration, bundle ID,
Google URL schemes and signing setup; they have not been configured or certified
by the Android work. Windows/Linux use local notes without Google sign-in.

## Validation

`test/account_test.dart` covers persisted/current SDK identity, live session
changes, cancellation, retry, duplicate operations, sign-out preservation,
App Lock invariants, disposal, narrow large-text account UI and navigation.
`test/account_service_test.dart` verifies credential exchange, configuration
fallback and sign-out/error semantics with SDK fakes. Real provider/device login
remains an explicit manual check, not a claim made by fake-based tests.

## Sources

- [Firebase Flutter federated sign-in](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Firebase Flutter session state and persistence](https://firebase.google.com/docs/auth/flutter/start)
- [Firebase Android configuration](https://firebase.google.com/docs/android/setup)
