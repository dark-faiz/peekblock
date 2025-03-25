import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:peekblock/pages/LoginScreen.dart'; // Ensure this is the correct path

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ✅ Initialize Firebase

  runApp(
    const MaterialApp(home: LoginScreen(), debugShowCheckedModeBanner: false),
  );
}
