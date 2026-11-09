import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UnreadChatIcon extends StatefulWidget {
  final VoidCallback onPressed;
  final Color iconColor;

  const UnreadChatIcon({
    super.key,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  @override
  State<UnreadChatIcon> createState() => _UnreadChatIconState();
}

class _UnreadChatIconState extends State<UnreadChatIcon> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _previousUnreadCount = 0;
  bool _isFirstLoad = true;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _triggerFeedback() async {
    HapticFeedback.mediumImpact();
    try {
      await _audioPlayer.play(AssetSource('sounds/message_notification.mp3'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return IconButton(
        icon: Icon(Icons.chat_bubble_outline, color: widget.iconColor),
        onPressed: widget.onPressed,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        if (!_isFirstLoad && unreadCount > _previousUnreadCount) {
          _triggerFeedback();
        }

        _previousUnreadCount = unreadCount;
        _isFirstLoad = false;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: widget.iconColor),
              onPressed: widget.onPressed,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}