import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:peekblock/services/auth_service.dart';
import 'CameraScannerScreen.dart'; // Scanner screen after login
import 'create_account_screen.dart'; // Sign-up screen
import 'forgot_password_screen.dart'; // Forgot password screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false; // To show a loading indicator

  // ✅ Login Function
  void _login() async {
    setState(() => _isLoading = true);

    try {
      User? user = await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CameraScannerScreen()),
        );
      } else {
        _showError("Login failed. Check your credentials.");
      }
    } catch (e) {
      _showError("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  // ✅ Show Error Messages
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage(
                'lib/assets/logo/logo.png', // ✅ Ensure this file exists
              ), // ✅ Ensure this file exists
            ),
            const SizedBox(height: 20),
            const Text(
              "Welcome back",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email Address",
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );
              },
              child: const Text(
                "Forgot Password?",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            _isLoading
                ? const CircularProgressIndicator() // ✅ Show loading animation
                : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text("Login"),
                ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateProfileScreen(),
                  ),
                );
              },
              child: const Text(
                "Don't have an account? Create →",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScannerScreen(),
                  ),
                ); // Allow guest to access scanner
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text("Continue as Guest"),
            ),
          ],
        ),
      ),
    );
  }
}
