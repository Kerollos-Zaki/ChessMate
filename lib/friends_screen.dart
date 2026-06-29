import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chessmate/services/social_service.dart';
import 'package:chessmate/widgets/custom_button.dart';
import 'package:chessmate/widgets/custom_text_field.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SocialService _socialService = SocialService();
  bool _isLoading = false;

  void _addFriend() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    String result = await _socialService.sendFriendRequest(_searchController.text.trim());

    setState(() => _isLoading = false);
    if (!mounted) return;

    _searchController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: result.contains("sent") ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        )
    );
  }

  void _confirmUnfriend(BuildContext context, String friendshipId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Remove Friend", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove $username from your friends list?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _socialService.removeFriend(friendshipId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$username removed."), backgroundColor: Colors.redAccent)
              );
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Friends & Matchmaking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: CustomTextField(
                    controller: _searchController,
                    label: "Friend's Email",
                    hint: "Enter email...",
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _isLoading
                      ? Container(
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)
                    ),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
                      : SizedBox(
                    height: 56,
                    child: CustomButton(text: "Add", onPressed: _addFriend),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text("Friend Requests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              flex: 1,
              child: StreamBuilder<QuerySnapshot>(
                stream: _socialService.getPendingRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white24));
                  var requests = snapshot.data!.docs;

                  if (requests.isEmpty) {
                    return Center(
                      child: Text("No pending requests.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    );
                  }

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      var req = requests[index];
                      String senderId = req['senderId'];

                      return FutureBuilder<Map<String, dynamic>?>(
                          future: _socialService.getUserProfile(senderId),
                          builder: (context, userSnapshot) {
                            // While waiting for data, display a clean skeleton card placeholder
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return _buildSkeletonCard();
                            }

                            String username = "Unknown User";
                            String? avatarPath;

                            if (userSnapshot.hasData && userSnapshot.data != null) {
                              var userData = userSnapshot.data!;
                              username = userData['username'] ?? 'Unknown User';
                              avatarPath = userData['photoUrl'];
                            }

                            return _buildUserCard(
                              username: username,
                              avatarPath: avatarPath,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                                    onPressed: () => _socialService.acceptRequest(req.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                                    onPressed: () => _socialService.declineRequest(req.id),
                                  ),
                                ],
                              ),
                            );
                          }
                      );
                    },
                  );
                },
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Colors.white24),
            ),

            const Text("My Friends", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: StreamBuilder<QuerySnapshot>(
                stream: _socialService.getAcceptedFriends(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white24));

                  var allFriends = snapshot.data!.docs;
                  var myFriends = allFriends.where((doc) =>
                  doc['senderId'] == _socialService.currentUserId ||
                      doc['receiverId'] == _socialService.currentUserId
                  ).toList();

                  if (myFriends.isEmpty) {
                    return Center(
                      child: Text("You don't have any friends yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    );
                  }

                  return ListView.builder(
                    itemCount: myFriends.length,
                    itemBuilder: (context, index) {
                      var friendDoc = myFriends[index];
                      bool amISender = friendDoc['senderId'] == _socialService.currentUserId;
                      String friendId = amISender ? friendDoc['receiverId'] : friendDoc['senderId'];

                      return FutureBuilder<Map<String, dynamic>?>(
                          future: _socialService.getUserProfile(friendId),
                          builder: (context, userSnapshot) {
                            // While waiting for data, display a clean skeleton card placeholder
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return _buildSkeletonCard();
                            }

                            String username = "Unknown User";
                            String? avatarPath;

                            if (userSnapshot.hasData && userSnapshot.data != null) {
                              var userData = userSnapshot.data!;
                              username = userData['username'] ?? 'Unknown User';
                              avatarPath = userData['photoUrl'];
                            }

                            return _buildUserCard(
                              username: username,
                              avatarPath: avatarPath,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      await _socialService.sendGameChallenge(friendId);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Challenge sent to $username!"),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.blueAccent,
                                        ),
                                      );
                                    },
                                    child: const Text("Challenge", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                    tooltip: "Unfriend",
                                    onPressed: () => _confirmUnfriend(context, friendDoc.id, username),
                                  ),
                                ],
                              ),
                            );
                          }
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Beautiful UI Card Builder
  Widget _buildUserCard({required String username, required String? avatarPath, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          avatarPath != null && avatarPath.isNotEmpty
              ? CircleAvatar(
            radius: 24,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage(avatarPath),
            onBackgroundImageError: (exception, stackTrace) {},
          )
              : CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: Colors.white70),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // --- NEW: SKELETON LOADER CARD ---
  // This runs while the background data is downloading so the old image never flickers!
  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 40),
          Container(
            width: 80,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
          )
        ],
      ),
    );
  }
}