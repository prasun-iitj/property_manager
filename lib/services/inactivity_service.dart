import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';

class InactivityService {

  static Timer? _timer;

  static const Duration timeout = Duration(minutes: 15);

  static void startTimer(BuildContext context) {

    _timer?.cancel();

    _timer = Timer(timeout, () async {

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

      }

    });

  }

  static void resetTimer(BuildContext context) {
    startTimer(context);
  }

  static void stopTimer() {
    _timer?.cancel();
  }

}