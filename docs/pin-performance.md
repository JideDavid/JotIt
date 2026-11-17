# PIN verification

Android uses `PBKDF2WithHmacSHA256` through a Flutter platform channel on a serial background task queue. The UI thread does not perform key derivation. The existing `pbkdf2-sha256:600000` record format, 16-byte random salt, 600000 iterations, 256-bit output, constant-time digest comparison and lock attempt cooldowns are retained. Both App Lock and shared note PINs use this path; existing records need no reset or migration.

Other platforms and older/test hosts without the native method retain the compatible Dart isolate implementation (Web Crypto is used by the cryptography package where supported). Native errors and invalid results fail closed; unsupported algorithm availability can fall back to Dart. No PIN, salt or digest is logged.

The independent compatibility vector uses a synthetic PIN and was generated with Node.js `crypto.pbkdf2Sync`. The native Java implementation and Dart fallback are checked against the same vector. Run:

```powershell
javac -d .dart_tool/pin-native-test android/app/src/main/java/com/zaleltech/jot_it/PinKeyDerivation.java test/java/PinKeyDerivationTest.java
java -cp .dart_tool/pin-native-test PinKeyDerivationTest
flutter test test/pin_hasher_test.dart test/auth_view_model_test.dart test/pin_auto_submit_test.dart test/hive_local_storage_service_test.dart
```

Desktop compatibility tests do not establish mobile latency. After installing the release, measure from the fourth PIN digit to unlock on the target phone, for both a correct and incorrect PIN. Check responsiveness, background/relock behavior, and the existing wrong-attempt cooldown. Never record or expose the real PIN while measuring.
