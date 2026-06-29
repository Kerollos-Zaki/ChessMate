import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'sound_service.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late chess.Chess game;
  int? selectedIndex;
  List<int> validMoves = [];

  // true  = it's the player's turn to tap the board
  // false = waiting for the Pi / Stockfish to respond
  bool _isPlayerTurn = true;
  bool _isWaitingForPi = false;

  StreamSubscription<DatabaseEvent>? _fenSubscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    game = chess.Chess();
    _initGame();
  }

  /// Reset Firebase state then start listening for Pi FEN updates.
  Future<void> _initGame() async {
    // Clear any leftover move from a previous session
    await _dbRef.child('pending_move').remove();
    // Write the starting FEN so the Pi knows a new game began
    await _dbRef.child('game_state/fen').set(chess.Chess.DEFAULT_POSITION);

    _fenSubscription = _dbRef.child('game_state/fen').onValue.listen((event) {
      final String? fen = event.snapshot.value as String?;
      if (fen == null) return;

      // Only react when it's NOT our own position —
      // i.e. when the Pi has written a new FEN after Stockfish moved.
      if (_isWaitingForPi && fen != game.fen) {
        final updated = chess.Chess();
        if (updated.load(fen)) {
          setState(() {
            game = updated;
            _isWaitingForPi = false;
            _isPlayerTurn = true;
          });
          SoundService.playButtonSound(context);
          _checkGameOver();
        }
      }
    });
  }

  @override
  void dispose() {
    _fenSubscription?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Player tap handler
  // ──────────────────────────────────────────────
  void _onSquareTap(int index) {
    // Block input while waiting for the Pi
    if (!_isPlayerTurn || _isWaitingForPi) return;

    setState(() {
      final square = _indexToSquare(index);

      if (selectedIndex == null) {
        // First tap: select a WHITE piece (player is always White)
        final piece = game.get(square);
        if (piece != null && piece.color == chess.Color.WHITE) {
          selectedIndex = index;
          validMoves = _getValidMoves(square);
          SoundService.playButtonSound(context);
        }
      } else {
        final fromSquare = _indexToSquare(selectedIndex!);

        bool success = game.move({
          'from': fromSquare,
          'to': square,
          'promotion': 'q',
        });

        if (success) {
          SoundService.playButtonSound(context);

          // ── THE KEY FIX ──
          // 1. Send the move in UCI format to the Pi.
          // 2. DO NOT write the FEN here — let the Pi write it after Stockfish responds.
          // 3. Set _isWaitingForPi so the listener knows the next FEN update is from Pi.
          final uciMove = '$fromSquare$square';
          _dbRef.child('pending_move').set(uciMove);

          selectedIndex = null;
          validMoves = [];
          _isPlayerTurn = false;
          _isWaitingForPi = true;

          _checkGameOver(); // check if player just checkmated the AI
        } else {
          // Invalid move: try selecting a different white piece instead
          final piece = game.get(square);
          if (piece != null && piece.color == chess.Color.WHITE) {
            selectedIndex = index;
            validMoves = _getValidMoves(square);
            SoundService.playButtonSound(context);
          } else {
            selectedIndex = null;
            validMoves = [];
          }
        }
      }
    });
  }

  // ──────────────────────────────────────────────
  // Game-over detection
  // ──────────────────────────────────────────────
  void _checkGameOver() {
    if (!game.game_over) return;

    if (game.in_checkmate) {
      // game.turn is the side that HAS been mated (no moves left)
      if (game.turn == chess.Color.BLACK) {
        // Black (AI) is mated → player wins
        SoundService.playWinSound(context);
        _showEndDialog('Checkmate — You Win! 🎉');
      } else {
        // White (player) is mated → player loses
        SoundService.playGameOverSound(context);
        _showEndDialog('Checkmate — You Lose!');
      }
    } else if (game.in_draw) {
      _showEndDialog('Draw!');
    } else {
      _showEndDialog('Game Over');
    }
  }

  void _showEndDialog(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () async {
              // Clean up Firebase and restart
              await _dbRef.child('pending_move').remove();
              await _dbRef.child('game_state/fen')
                  .set(chess.Chess.DEFAULT_POSITION);
              if (mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back to menu
              }
            },
            child: const Text('Back to Menu',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Coordinate helpers
  // ──────────────────────────────────────────────
  String _indexToSquare(int index) {
    final row = 7 - (index ~/ 8);
    final col = index % 8;
    return '${String.fromCharCode(97 + col)}${row + 1}';
  }

  List<int> _getValidMoves(String square) {
    return game
        .moves({'square': square, 'verbose': true})
        .map((m) => _squareToIndex(m['to'].toString()))
        .toList();
  }

  int _squareToIndex(String square) {
    final col = square.codeUnitAt(0) - 97;
    final row = int.parse(square[1]) - 1;
    return (7 - row) * 8 + col;
  }

  // ──────────────────────────────────────────────
  // Piece images
  // ──────────────────────────────────────────────
  Widget _getPieceWidget(chess.Piece? piece) {
    if (piece == null) return const SizedBox.shrink();
    final isWhite = piece.color == chess.Color.WHITE;
    final type = piece.type.toString().toLowerCase();
    final colorCode = isWhite ? 'l' : 'd';
    final url =
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '${_getWikiHash(type, colorCode)}/Chess_$type${colorCode}t45.svg/240px-Chess_$type${colorCode}t45.svg.png';
    return Image.network(url, width: 40, height: 40);
  }

  String _getWikiHash(String p, String c) {
    const hashes = {
      'kl': '4/42', 'kd': 'f/f0', 'ql': '1/15', 'qd': '4/47',
      'rl': '7/72', 'rd': 'f/ff', 'bl': 'b/b1', 'bd': '9/98',
      'nl': '7/70', 'nd': 'e/ef', 'pl': '4/45', 'pd': 'c/c7',
    };
    return hashes['$p$c'] ?? '4/45';
  }

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: (user != null)
            ? FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots()
            : const Stream.empty(),
        builder: (context, userSnapshot) {
          String username = 'You';
          String? photoUrl;
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            username = data['username'] ?? 'User';
            photoUrl = data['photoUrl'] as String?;
          }

          return Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
              Column(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          _buildRoundButton(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: () async {
                              await _dbRef.child('pending_move').remove();
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 20),
                          const Text('vs Stockfish',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // AI side (Black)
                        _buildPlayerInfo('Stockfish AI', isWhite: false),
                        const SizedBox(height: 16),

                        // Waiting indicator
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isWaitingForPi
                              ? Padding(
                            key: const ValueKey('thinking'),
                            padding:
                            const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white54,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('Stockfish is thinking...',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                        fontSize: 13)),
                              ],
                            ),
                          )
                              : const SizedBox(
                              key: ValueKey('idle'), height: 0),
                        ),

                        // Chess board
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8),
                                itemCount: 64,
                                itemBuilder: (context, index) {
                                  final row = index ~/ 8;
                                  final col = index % 8;
                                  final isLight = (row + col) % 2 == 0;
                                  final square = _indexToSquare(index);
                                  final piece = game.get(square);
                                  final isSelected = selectedIndex == index;
                                  final isValidMove =
                                  validMoves.contains(index);

                                  return GestureDetector(
                                    onTap: () => _onSquareTap(index),
                                    child: Container(
                                      color: isLight
                                          ? Colors.white
                                          .withValues(alpha: 0.15)
                                          : Colors.white
                                          .withValues(alpha: 0.05),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (isSelected)
                                            Container(
                                                color: Colors.yellow
                                                    .withValues(alpha: 0.3)),
                                          if (isValidMove)
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white38,
                                              ),
                                            ),
                                          // Dim board while waiting for Pi
                                          if (_isWaitingForPi)
                                            Container(
                                                color: Colors.black
                                                    .withValues(alpha: 0.25)),
                                          _getPieceWidget(piece),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Player side (White)
                        _buildPlayerInfo(username,
                            isWhite: true, photoUrl: photoUrl),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerInfo(String name,
      {required bool isWhite, String? photoUrl}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: photoUrl != null
                    ? ClipOval(
                  child: photoUrl.startsWith('http')
                      ? Image.network(photoUrl, fit: BoxFit.cover)
                      : Image.asset(photoUrl, fit: BoxFit.cover),
                )
                    : Icon(
                  isWhite ? Icons.person : Icons.computer,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(isWhite ? 'White ♙' : 'Black ♟',
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildRoundButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: () {
        SoundService.playButtonSound(context);
        onPressed();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}