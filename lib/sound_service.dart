import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'package:flutter/material.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playSound(BuildContext context, String soundPath) async {
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.soundEnabled) {
        debugPrint('Attempting to play sound: $soundPath');
        await _player.stop();
        // AssetSource by default looks into the assets/ folder
        await _player.play(AssetSource(soundPath));
      } else {
        debugPrint('Sound suppressed: Settings disabled');
      }
    } catch (e) {
      debugPrint('Error playing sound ($soundPath): $e');
    }
  }

  static void playButtonSound(BuildContext context) {
    playSound(context, 'sounds/anybuttton.mp3');
  }

  static void playWinSound(BuildContext context) {
    playSound(context, 'sounds/win.mp3');
  }

  static void playGameOverSound(BuildContext context) {
    playSound(context, 'sounds/Game over.mp3');
  }

  static void playNotificationSound(BuildContext context) {
    playSound(context, 'sounds/notification.mp3');
  }
}
