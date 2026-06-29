import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;
  String get currentUserEmail => _auth.currentUser!.email ?? 'Unknown User';

  // --- FETCH SPECIFIC USER PROFILE ---
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  // --- FRIEND SYSTEM LOGIC ---
  Future<String> sendFriendRequest(String targetEmail) async {
    try {
      if (targetEmail.toLowerCase() == currentUserEmail.toLowerCase()) {
        return "You cannot add yourself.";
      }

      var userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        return "User not found. Check the email.";
      }

      var targetUserDoc = userQuery.docs.first;
      String targetUserId = targetUserDoc.id;

      var existingRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: targetUserId)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return "Request already sent!";
      }

      await _firestore.collection('friend_requests').add({
        'senderId': currentUserId,
        'receiverId': targetUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return "Friend request sent!";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  Stream<QuerySnapshot> getPendingRequests() {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  Future<void> declineRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  // NEW: Remove an accepted friend
  Future<void> removeFriend(String friendshipId) async {
    await _firestore.collection('friend_requests').doc(friendshipId).delete();
  }

  Stream<QuerySnapshot> getAcceptedFriends() {
    return _firestore
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  // --- MATCHMAKING LOGIC ---
  Future<void> sendGameChallenge(String friendId) async {
    await _firestore.collection('game_invites').add({
      'senderId': currentUserId,
      'receiverId': friendId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getIncomingChallenges() {
    return _firestore
        .collection('game_invites')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<String> acceptChallenge(String inviteId, String challengerId) async {
    DocumentReference gameRef = await _firestore.collection('games').add({
      'whitePlayer': challengerId,
      'blackPlayer': currentUserId,
      'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'status': 'active',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('game_invites').doc(inviteId).update({
      'status': 'accepted',
      'gameId': gameRef.id,
    });

    return gameRef.id;
  }
}