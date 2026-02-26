import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:firebase_database/firebase_database.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late chess.Chess game;
  int? selectedIndex;
  List<int> validMoves = [];

  // Realtime Database reference for your Belgium Server
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    game = chess.Chess();
    _setupFirebaseListener();
  }

  // Listen for moves made by the AI or on the physical board
  void _setupFirebaseListener() {
    _dbRef.child('game_state/fen').onValue.listen((event) {
      final String? fen = event.snapshot.value as String?;
      if (fen != null && fen != game.fen) {
        setState(() {
          game.load(fen);
        });
      }
    });
  }

  void _onSquareTap(int index) {
    setState(() {
      final square = _indexToSquare(index);

      if (selectedIndex == null) {
        // Selecting a piece
        final piece = game.get(square);
        if (piece != null && piece.color == (game.turn == chess.Color.WHITE ? chess.Color.WHITE : chess.Color.BLACK)) {
          selectedIndex = index;
          validMoves = _getValidMoves(square);
        }
      } else {
        // Attempting a move
        final fromSquare = _indexToSquare(selectedIndex!);
        final toSquare = square;

        // FIX: handle move result correctly
        // make_move returns true/false, it does not return the move object itself
        bool success = game.move({
          'from': fromSquare,
          'to': toSquare,
          'promotion': 'q',
        });

        if (success) {
          // Send the move to the Raspberry Pi via Firebase
          String uciMove = "$fromSquare$toSquare";
          _dbRef.child('pending_move').set(uciMove);
          _dbRef.child('game_state/fen').set(game.fen);

          selectedIndex = null;
          validMoves = [];
        } else {
          // If move fails, check if user clicked another of their own pieces to select it
          final piece = game.get(square);
          if (piece != null && piece.color == (game.turn == chess.Color.WHITE ? chess.Color.WHITE : chess.Color.BLACK)) {
            selectedIndex = index;
            validMoves = _getValidMoves(square);
          } else {
            selectedIndex = null;
            validMoves = [];
          }
        }
      }
    });
  }

  String _indexToSquare(int index) {
    int row = 7 - (index ~/ 8);
    int col = index % 8;
    return '${String.fromCharCode(97 + col)}${row + 1}';
  }

  List<int> _getValidMoves(String square) {
    return game
        .moves({'square': square, 'verbose': true})
        .map((m) => _squareToIndex(m['to'].toString()))
        .toList();
  }

  int _squareToIndex(String square) {
    int col = square.codeUnitAt(0) - 97;
    int row = int.parse(square[1]) - 1;
    return (7 - row) * 8 + col;
  }

  Widget _getPieceWidget(chess.Piece? piece) {
    if (piece == null) return const SizedBox.shrink();
    final isWhite = piece.color == chess.Color.WHITE;
    String type = piece.type.toString().toLowerCase();

    // Map internal types to URL segments
    Map<String, String> typeMap = {
      'k': 'k', 'q': 'q', 'r': 'r', 'b': 'b', 'n': 'n', 'p': 'p'
    };

    String code = typeMap[type] ?? 'p';
    String colorCode = isWhite ? 'l' : 'd';
    String url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '${_getWikiHash(code, colorCode)}/Chess_${code}${colorCode}t45.svg/240px-Chess_${code}${colorCode}t45.svg.png';

    return Image.network(url, width: 40, height: 40);
  }

  // Helper for Wikimedia Commons URLs
  String _getWikiHash(String p, String c) {
    Map<String, String> hashes = {
      'kl': '4/42', 'kd': 'f/f0', 'ql': '1/15', 'qd': '4/47',
      'rl': '7/72', 'rd': 'f/ff', 'bl': 'b/b1', 'bd': '9/98',
      'nl': '7/70', 'nd': 'e/ef', 'pl': '4/45', 'pd': 'c/c7'
    };
    return hashes['$p$c'] ?? '4/45';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background soft glow
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _buildRoundButton(
                        icon: Icons.arrow_back_ios_new,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'Match',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildPlayerInfo('AI Opponent', isWhite: false),
                    const SizedBox(height: 20),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              final row = index ~/ 8;
                              final col = index % 8;
                              final isLight = (row + col) % 2 == 0;
                              final square = _indexToSquare(index);
                              final piece = game.get(square);
                              bool isSelected = selectedIndex == index;
                              bool isValidMove = validMoves.contains(index);

                              return GestureDetector(
                                onTap: () => _onSquareTap(index),
                                child: Container(
                                  color: isLight ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (isSelected) Container(color: Colors.yellow.withValues(alpha: 0.3)),
                                      if (isValidMove)
                                        Container(
                                          width: 12, height: 12,
                                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white38),
                                        ),
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
                    const SizedBox(height: 20),
                    _buildPlayerInfo('You', isWhite: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildPlayerInfo(String name, {required bool isWhite}) {
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
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(isWhite ? 'White' : 'Black', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44, height: 44,
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