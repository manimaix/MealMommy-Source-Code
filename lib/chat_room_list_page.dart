import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class ChatRoomListPage extends StatefulWidget {
  final String currentUserId;
  final List<Map<String, dynamic>> chatRooms;

  const ChatRoomListPage({
    Key? key,
    required this.currentUserId,
    required this.chatRooms,
  }) : super(key: key);

  @override
  _ChatRoomListPageState createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Chats'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: widget.chatRooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No active chats',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Accept an order to start chatting!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.chatRooms.length,
              itemBuilder: (context, index) {
                final chatRoom = widget.chatRooms[index];
                return _buildChatRoomTile(chatRoom);
              },
            ),
    );
  }

  Widget _buildChatRoomTile(Map<String, dynamic> chatRoom) {
    final groupId = chatRoom['group_id'] ?? '';
    final lastMessage = chatRoom['lastMessage'] ?? 'No messages yet';
    final lastMessageTime = chatRoom['lastMessageTime'] as Timestamp?;
    final participants = List<String>.from(chatRoom['participants'] ?? []);
    
    // Format time
    String timeText = '';
    if (lastMessageTime != null) {
      final messageTime = lastMessageTime.toDate();
      final now = DateTime.now();
      final difference = now.difference(messageTime);
      
      if (difference.inDays > 0) {
        timeText = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeText = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeText = '${difference.inMinutes}m ago';
      } else {
        timeText = 'Just now';
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[700],
          child: Icon(
            Icons.group,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Order Chat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupId.isNotEmpty)
              Text(
                'Order: ${groupId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            SizedBox(height: 2),
            Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${participants.length} participants',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                chatRoomId: chatRoom['id'],
                currentUserId: widget.currentUserId,
              ),
            ),
          );
        },
      ),
    );
  }
}
