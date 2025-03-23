import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            TextButton(onPressed: () {}, child: const Text("Change Photo")),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Your Name"),
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email Address"),
            ),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: "Your Age"),
            ),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Your Title"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Save logic here
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
