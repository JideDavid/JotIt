import 'package:firebase_core/firebase_core.dart';

/// Public Firebase web registration values; never a Gemini API key.
FirebaseOptions? get firebaseWebOptions {
  const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  const sender = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
  const domain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  if ([appId, apiKey, projectId, sender, domain].any((v) => v.isEmpty)) {
    return null;
  }
  return const FirebaseOptions(
    appId: appId,
    apiKey: apiKey,
    projectId: projectId,
    messagingSenderId: sender,
    authDomain: domain,
  );
}
