import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/site_list_screen.dart';
import 'services/emi_checker.dart';
import 'services/inactivity_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static bool _emiCheckStarted = false;

  void _startAuthenticatedServices(BuildContext context) {
    InactivityService.startTimer(context);

    if (_emiCheckStarted) return;
    _emiCheckStarted = true;
    unawaited(EmiChecker.checkEmiDue());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          _startAuthenticatedServices(context);

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final role =
                  (roleSnapshot.data?.data()?['role'] ?? 'staff').toString();
              if (role == 'admin') return const DashboardScreen();
              return SiteListScreen(role: role);
            },
          );
        }

        InactivityService.stopTimer();
        _emiCheckStarted = false;
        return const LoginScreen();
      },
    );
  }
}
