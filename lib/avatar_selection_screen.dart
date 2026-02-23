import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvatarSelectionScreen extends StatelessWidget {
  const AvatarSelectionScreen({super.key});

  final List<Map<String, String>> avatars = const [
    {'name': 'Boy 1', 'path': 'assets/boy 1.png'},
    {'name': 'Boy 2', 'path': 'assets/boy 2.png'},
    {'name': 'Boy 3', 'path': 'assets/Boy 3.png'},
    {'name': 'Boy 4', 'path': 'assets/boy 4.png'},
    {'name': 'Boy 5', 'path': 'assets/boy 5.png'},
    {'name': 'Boy 6', 'path': 'assets/boy 6.png'},
    {'name': 'Girl 1', 'path': 'assets/Girl 1.png'},
    {'name': 'Girl 2', 'path': 'assets/girl 2.png'},
    {'name': 'Girl 3', 'path': 'assets/girl 3.png'},
    {'name': 'Girl 4', 'path': 'assets/girl 4.png'},
    {'name': 'Girl 5', 'path': 'assets/girl 5.png'},
    {'name': 'Girl 6', 'path': 'assets/girl 6.png'},
  ];

  Future<void> _updateAvatar(BuildContext context, String assetPath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'photoUrl': assetPath});
        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile picture: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Avatar', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          final avatar = avatars[index];
          return InkWell(
            onTap: () => _updateAvatar(context, avatar['path']!),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        avatar['path']!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      avatar['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
