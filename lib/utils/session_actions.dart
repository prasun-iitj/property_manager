import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Signs out of Firebase (and Google on web) so another account can log in.
Future<void> signOutCompletely() async {
  if (kIsWeb) {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
  await FirebaseAuth.instance.signOut();
}
