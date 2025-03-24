import 'package:flutter/material.dart';
import 'CameraScannerScreen.dart'; // Import the Scanner Screen
import 'create_account_screen.dart'; // Import the Create Account Screen
import 'forgot_password_screen.dart'; // Import the Forgot Password Screen

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                'lib/assets/logo/logo.png',
              ), // ✅ Use forward slashes `/`
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
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScannerScreen(),
                  ),
                );
              },
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScannerScreen(),
                  ), // Allow guest to access scanner
                );
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
