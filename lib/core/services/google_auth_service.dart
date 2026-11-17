import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = kIsWeb ? null : googleSignIn ?? GoogleSignIn(),
      unavailableReason = null;

  const GoogleAuthService.unavailable([
    this.unavailableReason =
        'Account sign-in is not configured for this build. Your local notes are still available.',
  ]) : _auth = null,
       _googleSignIn = null;

  final FirebaseAuth? _auth;
  final GoogleSignIn? _googleSignIn;
  final String? unavailableReason;

  bool get isAvailable => _auth != null;
  User? get currentUser => _auth?.currentUser;
  Stream<User?> get userChanges =>
      _auth?.userChanges() ?? Stream<User?>.value(null);

  static Future<GoogleAuthService> initialize({
    FirebaseOptions? options,
    Future<void> Function()? initializeFirebase,
    GoogleAuthService Function()? createService,
  }) async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return const GoogleAuthService.unavailable(
        'Google sign-in is not supported on this platform. Your local notes are still available.',
      );
    }
    try {
      if (initializeFirebase != null) {
        await initializeFirebase();
      } else {
        await Firebase.initializeApp(options: options);
      }
      return createService?.call() ?? GoogleAuthService();
    } catch (_) {
      return const GoogleAuthService.unavailable();
    }
  }

  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) throw StateError('Account sign-in is unavailable.');
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      return (await auth.signInWithPopup(provider)).user;
    }
    final googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return (await auth.signInWithCredential(credential)).user;
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
  }
}
