import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DifficultyScreen extends StatelessWidget {
  const DifficultyScreen({super.key});

  // Helper function to update Firebase
  Future<void> _selectDifficulty(BuildContext context, String level, int skillValue) async {
    final database = FirebaseDatabase.instance.ref();

    try {
      // 1. Tell the Pi we are playing against the AI
      await database.child('settings/game_mode').set('AI');

      // 2. Set the Stockfish skill level (0-20 scale usually used by the engine)
      await database.child('settings/ai_level').set(skillValue);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mode: AI vs $level. Board is ready!')),
        );
        // Navigate to your game board screen here
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _buildRoundButton(
                        icon: Icons.arrow_back_ios_new,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'AI Difficulty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Select Challenge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the strength of your AI opponent',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),

                      _DifficultyCard(
                        level: 'Beginner',
                        description: 'Casual game, perfect for practice',
                        icon: Icons.child_care_outlined,
                        color: Colors.greenAccent,
                        onTap: () => _selectDifficulty(context, 'Beginner', 3),
                      ),
                      const SizedBox(height: 20),
                      _DifficultyCard(
                        level: 'Intermediate',
                        description: 'A balanced and smart opponent',
                        icon: Icons.psychology_outlined,
                        color: Colors.blueAccent,
                        onTap: () => _selectDifficulty(context, 'Intermediate', 8),
                      ),
                      const SizedBox(height: 20),
                      _DifficultyCard(
                        level: 'Advanced',
                        description: 'For players seeking a real challenge',
                        icon: Icons.bolt_outlined,
                        color: Colors.orangeAccent,
                        onTap: () => _selectDifficulty(context, 'Advanced', 15),
                      ),
                      const SizedBox(height: 20),
                      _DifficultyCard(
                        level: 'Grandmaster',
                        description: 'Maximum precision and strategy',
                        icon: Icons.workspace_premium_outlined,
                        color: Colors.redAccent,
                        onTap: () => _selectDifficulty(context, 'Grandmaster', 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String level;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.level,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}