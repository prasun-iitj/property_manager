import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'site_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final email = TextEditingController();
  final password = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {

    if (email.text.trim().isEmpty || password.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email and password")),
      );

      return;
    }

    setState(() => isLoading = true);

    try {

      var userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      String uid = userCredential.user!.uid;

      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String role = doc['role'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              role == "admin"
                  ? const DashboardScreen()
                  : SiteListScreen(role: role),
        ),
      );

    } on FirebaseAuthException catch (e) {

      String message = "Login Failed";

      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );

    } finally {

      if (mounted) {
        setState(() => isLoading = false);
      }

    }
  }

  Future<void> resetPassword() async {

    String userEmail = email.text.trim();

    if (userEmail.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email first")),
      );

      return;
    }

    try {

      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: userEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset link sent to your email"),
        ),
      );

    } on FirebaseAuthException catch (e) {

      String message = "Failed to send reset email";

      if (e.code == 'user-not-found') {
        message = "No account found with this email";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        decoration: const BoxDecoration(

          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2A5298)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),

        ),

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 28),

            child: Card(

              elevation: 8,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              child: Padding(

                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 32,
                ),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    /// Icon

                    const Icon(
                      Icons.home_work_rounded,
                      size: 60,
                      color: Color(0xFF1E3A8A),
                    ),

                    const SizedBox(height: 10),

                    /// Title

                    const Text(
                      "Property Manager",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// Email

                    TextField(
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// Password

                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// Forgot password

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: resetPassword,
                        child: const Text("Forgot Password?"),
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// Login Button

                    SizedBox(
                      width: double.infinity,
                      height: 48,

                      child: ElevatedButton(

                        onPressed: isLoading ? null : login,

                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}