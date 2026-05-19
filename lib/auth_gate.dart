import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/site_list_screen.dart';
import 'services/emi_checker.dart';
import 'services/inactivity_service.dart';
import 'utils/session_actions.dart';

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

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final userDoc = roleSnapshot.data;
              if (userDoc == null || !userDoc.exists) {
                return _UnregisteredUserScreen(email: user.email);
              }

              final role = (userDoc.data()?['role'] ?? 'staff').toString();
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

/// Shown when Firebase Auth succeeded but there is no `users/{uid}` profile.
class _UnregisteredUserScreen extends StatelessWidget {
  final String? email;

  const _UnregisteredUserScreen({this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Color(0xFF1E3A8A)),
            const SizedBox(height: 16),
            const Text(
              'This account is not registered',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              email != null && email!.isNotEmpty
                  ? 'Signed in as: $email'
                  : 'Your sign-in is not linked to Property Manager.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask the administrator to add your account in Firebase, or sign in with the admin email and password you normally use.',
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                await signOutCompletely();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out & try another account'),
            ),
          ],
        ),
      ),
    );
  }
}
