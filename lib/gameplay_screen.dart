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
  chess.Chess _game = chess.Chess();
  String _lastFen = '';

  // Which squares were involved in the last move (for highlighting)
  int? _lastFromIndex;
  int? _lastToIndex;

  // Whose turn label to show
  bool _isPlayerTurn = true; // White moves first

  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _fenSub;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _listenToBoard();
  }

  @override
  void dispose() {
    _fenSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Just listen — the Pi owns the board state
  // ─────────────────────────────────────────────
  void _listenToBoard() {
    _fenSub = _db.child('game_state/fen').onValue.listen((event) {
      final String? fen = event.snapshot.value as String?;
      if (fen == null || fen == _lastFen || !mounted) return;

      final updated = chess.Chess();
      if (!updated.load(fen)) {
        debugPrint('Invalid FEN from Pi: $fen');
        return;
      }

      // Detect the move that just happened by comparing positions
      int? fromIdx;
      int? toIdx;
      _detectLastMove(_game, updated, fromIdx, toIdx, (f, t) {
        fromIdx = f;
        toIdx = t;
      });

      SoundService.playButtonSound(context);

      setState(() {
        _game = updated;
        _lastFen = fen;
        _lastFromIndex = fromIdx;
        _lastToIndex = toIdx;
        // After Pi updates, White's turn = player; Black's turn = Stockfish thinking
        _isPlayerTurn = updated.turn == chess.Color.WHITE;
      });

      _checkGameOver();
    });
  }

  // Figure out which square changed between old and new position
  void _detectLastMove(
      chess.Chess oldGame,
      chess.Chess newGame,
      int? fromIdx,
      int? toIdx,
      void Function(int from, int to) onFound,
      ) {
    int? disappearedFrom;
    int? appearedTo;

    for (int i = 0; i < 64; i++) {
      final sq = _indexToSquare(i);
      final oldPiece = oldGame.get(sq);
      final newPiece = newGame.get(sq);

      if (oldPiece != null && newPiece == null) disappearedFrom = i;
      if (oldPiece == null && newPiece != null) appearedTo = i;
    }

    if (disappearedFrom != null && appearedTo != null) {
      onFound(disappearedFrom, appearedTo);
    }
  }

  // ─────────────────────────────────────────────
  // Game over
  // ─────────────────────────────────────────────
  void _checkGameOver() {
    if (!_game.game_over) return;

    String title;
    if (_game.in_checkmate) {
      title = _game.turn == chess.Color.BLACK
          ? 'Checkmate — You Win! 🎉'
          : 'Checkmate — Stockfish Wins!';
      if (_game.turn == chess.Color.BLACK) {
        SoundService.playWinSound(context);
      } else {
        SoundService.playGameOverSound(context);
      }
    } else {
      title = 'Draw!';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showEndDialog(title);
    });
  }

  void _showEndDialog(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Menu',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Coordinate helpers
  // ─────────────────────────────────────────────
  String _indexToSquare(int index) {
    final row = 7 - (index ~/ 8);
    final col = index % 8;
    return '${String.fromCharCode(97 + col)}${row + 1}';
  }

  // ─────────────────────────────────────────────
  // Piece widget
  // ─────────────────────────────────────────────
  static const Map<String, String> _symbols = {
    'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
  };

  Widget _getPieceWidget(chess.Piece? piece) {
    if (piece == null) return const SizedBox.shrink();
    final isWhite = piece.color == chess.Color.WHITE;
    final symbol = _symbols[piece.type.toString().toLowerCase()] ?? '';
    if (symbol.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWhite ? const Color(0xFFF0D9B5) : const Color(0xFF2C2C2C),
        border: Border.all(
          color: isWhite ? const Color(0xFF8B6914) : const Color(0xFFAAAAAA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 20,
            color: isWhite ? const Color(0xFF3D2000) : Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 32;
    final squareSize = boardSize / 8;

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _user != null
            ? FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .snapshots()
            : const Stream.empty(),
        builder: (context, snap) {
          String username = 'You';
          String? photoUrl;
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>;
            username = data['username'] ?? 'You';
            photoUrl = data['photoUrl'] as String?;
          }

          return Column(
            children: [
              // ── Header ──────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      _roundBtn(Icons.arrow_back_ios_new, () async {
                        _fenSub?.cancel();
                        if (mounted) Navigator.pop(context);
                      }),
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

              // ── Content ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Stockfish card — highlighted when it's thinking
                      _playerCard(
                        'Stockfish AI',
                        isWhite: false,
                        isActive: !_isPlayerTurn,
                      ),
                      const SizedBox(height: 8),

                      // Status bar
                      _statusBar(),

                      const SizedBox(height: 8),

                      // ── Chess board (display only) ──
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Column(
                            children: List.generate(8, (row) {
                              return SizedBox(
                                height: squareSize,
                                child: Row(
                                  children: List.generate(8, (col) {
                                    final index = row * 8 + col;
                                    return SizedBox(
                                      width: squareSize,
                                      height: squareSize,
                                      child: _buildSquare(context, index),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Player card — highlighted when it's their turn
                      _playerCard(
                        username,
                        isWhite: true,
                        photoUrl: photoUrl,
                        isActive: _isPlayerTurn,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSquare(BuildContext context, int index) {
    final row = index ~/ 8;
    final col = index % 8;
    final isLight = (row + col) % 2 == 0;
    final square = _indexToSquare(index);
    final piece = _game.get(square);

    final isLastFrom = index == _lastFromIndex;
    final isLastTo = index == _lastToIndex;

    Color bg = isLight
        ? const Color(0xFFEEEED2)
        : const Color(0xFF769656);

    // Highlight last move squares in yellow/gold
    if (isLastFrom || isLastTo) {
      bg = isLight
          ? const Color(0xFFF6F669)
          : const Color(0xFFBBCA44);
    }

    return Container(
      color: bg,
      child: Center(child: _getPieceWidget(piece)),
    );
  }

  Widget _statusBar() {
    final String message;
    final Color color;
    final bool showSpinner;

    if (_game.game_over) {
      message = 'Game Over';
      color = Colors.white54;
      showSpinner = false;
    } else if (_isPlayerTurn) {
      message = 'Your turn — make your move on the board';
      color = Colors.greenAccent;
      showSpinner = false;
    } else {
      message = 'Stockfish is thinking…';
      color = Colors.white54;
      showSpinner = true;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white38),
            ),
            const SizedBox(width: 10),
          ],
          Text(message,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _playerCard(String name,
      {required bool isWhite, String? photoUrl, bool isActive = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: photoUrl != null && isWhite
                ? ClipOval(
                child: photoUrl.startsWith('http')
                    ? Image.network(photoUrl, fit: BoxFit.cover)
                    : Image.asset(photoUrl, fit: BoxFit.cover))
                : Icon(isWhite ? Icons.person : Icons.computer,
                color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          if (isActive)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent,
              ),
            ),
          const SizedBox(width: 8),
          Text(isWhite ? '♙ White' : '♟ Black',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onPressed) {
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
          border:
          Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}