import 'package:firebase_database/firebase_database.dart';

class GameService {
  final _db = FirebaseDatabase.instance.ref();

  // Mode 1 & 3: Tell the Pi which mode we are in
  Future<void> setGameMode(String mode) async {
    // This triggers the 'get_current_mode' function in your Python cloud_sync.py
    await _db.child('settings/game_mode').set(mode);
  }

  // Mode 3: Send a remote move to the Pi
  Future<void> sendRemoteMove(String uciMove) async {
    await _db.child('pending_move').set(uciMove);
  }

  // Real-time listener for the board FEN
  Stream<DatabaseEvent> getBoardStream() {
    return _db.child('game_state/fen').onValue;
  }
}