import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/chat_service.dart';
import 'services/timer_utils_service.dart';

class ChatPage extends StatefulWidget {
  final String? chatRoomId;
  final String? groupOrderId;
  final List<String>? initialParticipants;
  final String? currentUserId;

  const ChatPage({
    super.key,
    this.chatRoomId,
    this.groupOrderId,
    this.initialParticipants,
    this.currentUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? currentChatRoomId;
  String? currentUserId;
  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    _initializeChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatRoom() async {
    if (widget.chatRoomId != null) {
      // Existing chatroom
      currentChatRoomId = widget.chatRoomId;
    } else if (widget.groupOrderId != null && widget.initialParticipants != null) {
      // Check if chat room already exists for this group order
      currentChatRoomId = await ChatService.getChatRoomForOrder(widget.groupOrderId!);
      
      if (currentChatRoomId == null) {
        // Create new chatroom for group order using ChatService
        currentChatRoomId = await _createChatRoomWithService();
      }
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<String?> _createChatRoomWithService() async {
    if (widget.groupOrderId == null || widget.initialParticipants == null) {
      return null;
    }

    try {
      // Parse participants to identify driver, vendor, and customers
      final participants = widget.initialParticipants!;
      
      // For simplicity, assume first participant is driver, second is vendor (if exists), rest are customers
      // This should be improved with proper role identification
      final driverId = currentUserId ?? '';
      final vendorId = participants.isNotEmpty ? participants[0] : '';
      final customerIds = participants.length > 1 
          ? participants.sublist(1).cast<String>() 
          : <String>[];
      
      final chatRoomId = await ChatService.createOrderChatRoom(
        groupOrderId: widget.groupOrderId!,
        driverId: driverId,
        vendorId: vendorId,
        customerIds: customerIds,
      );
      
      return chatRoomId;
    } catch (e) {
      throw e;
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentChatRoomId == null) return;
    
    setState(() {
      isSending = true;
    });

    try {
      final messageText = _messageController.text.trim();
      _messageController.clear();

      // Get current user name
      String senderName = 'Unknown User';
      
      // Try to get name from users collection
      try {
        final userDoc = await _firestore.collection('users').doc(currentUserId!).get();
        if (userDoc.exists && userDoc.data()?['name'] != null) {
          senderName = userDoc.data()!['name'];
        }
      } catch (e) {
        // Could not fetch user name - continue with default
      }

      // Add message to chatmessages collection
      await _firestore.collection('chatmessages').add({
        'chatRoomId': currentChatRoomId,
        'senderId': currentUserId!,
        'senderName': senderName,
        'text': messageText,
        'type': 'text',
        'sentAt': Timestamp.now(),
      });

      // Update chatroom last message
      await _firestore.collection('chatroom').doc(currentChatRoomId).update({
        'lastMessage': messageText,
        'lastMessageTime': Timestamp.now(),
      });

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isSending = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Chat...'),
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (currentChatRoomId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat Error'),
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Failed to initialize chat room',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Group Chat - ${widget.groupOrderId ?? 'Chat'}'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatmessages')
                  .where('chatRoomId', isEqualTo: currentChatRoomId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messageDocs = snapshot.data?.docs ?? [];
                
                // Sort manually by sentAt to avoid index requirement
                final messages = messageDocs.map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>
                }).toList();
                
                // Sort by sentAt ascending (oldest first)
                messages.sort((a, b) {
                  final aTime = a['sentAt'] as Timestamp?;
                  final bTime = b['sentAt'] as Timestamp?;
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  
                  return aTime.compareTo(bTime);
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    
                    return _buildMessageBubble(messageData);
                  },
                );
              },
            ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final isMyMessage = messageData['senderId'] == currentUserId;
    final isSystemMessage = messageData['senderId'] == 'system';
    final messageType = messageData['type'] ?? 'text';
    final sentAt = messageData['sentAt'] as Timestamp?;
    
    if (isSystemMessage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildSystemMessageContent(messageData['text'] ?? ''),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[200],
              child: Text(
                (messageData['senderName'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyMessage ? Colors.green[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Text(
                      messageData['senderName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  
                  if (messageType == 'text')
                    Text(
                      messageData['text'] ?? '',
                      style: TextStyle(
                        color: isMyMessage ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  Text(
                    TimerUtilsService.formatTimestamp(sentAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMyMessage ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[200],
              child: Text(
                (messageData['senderName'] ?? 'M')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessageContent(String text) {
    // Split the text by lines to process each line
    final lines = text.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Check if this line contains a QR code URL
      if (line.contains('QR') && (line.contains('https://') || line.contains('http://'))) {
        // Extract the URL from the line
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(line);
        if (urlMatch != null) {
          final qrUrl = urlMatch.group(0)!;
          final labelText = line.substring(0, urlMatch.start).trim();
          
          // Add the label text if it exists
          if (labelText.isNotEmpty) {
            widgets.add(
              Text(
                labelText,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            );
            widgets.add(const SizedBox(height: 8));
          }
          
          // Add the QR code image
          widgets.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  qrUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.qr_code,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          
          // Add some spacing after QR code
          if (i < lines.length - 1) {
            widgets.add(const SizedBox(height: 12));
          }
        } else {
          // Line mentions QR but no URL found, display as text
          widgets.add(
            Text(
              line,
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          );
          if (i < lines.length - 1) {
            widgets.add(const SizedBox(height: 4));
          }
        }
      } else if (line.isNotEmpty) {
        // Regular text line
        widgets.add(
          Text(
            line,
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 13,
              fontWeight: line.startsWith('🚛') || line.startsWith('✅') 
                  ? FontWeight.w600 
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        );
        if (i < lines.length - 1) {
          widgets.add(const SizedBox(height: 4));
        }
      }
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.green[600]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !isSending,
            ),
          ),
          
          const SizedBox(width: 8),
          
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSending ? Colors.grey : Colors.green[600],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSending ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Info'),
        content: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('chatroom').doc(currentChatRoomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            
            final chatRoomData = snapshot.data!.data() as Map<String, dynamic>?;
            if (chatRoomData == null) return const Text('Chat room not found');
            
            final participants = chatRoomData['participants'] as List<dynamic>? ?? [];
            final createdAt = chatRoomData['createdAt'] as Timestamp?;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Participants: ${participants.length}'),
                const SizedBox(height: 8),
                Text('Created: ${TimerUtilsService.formatTimestamp(createdAt)}'),
                const SizedBox(height: 8),
                Text('Group Order: ${widget.groupOrderId ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Status: ${chatRoomData['status'] ?? 'active'}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Chat Rooms List Page
class ChatRoomsListPage extends StatelessWidget {
  final String currentUserId;
  
  const ChatRoomsListPage({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chats'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ChatService.getUserChatRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatRooms = snapshot.data ?? [];

          if (chatRooms.isEmpty) {
            return const Center(
              child: Text(
                'No active chats.\nChats are created automatically for your deliveries.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoomData = chatRooms[index];
              
              return _buildChatRoomTile(context, chatRoomData);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatRoomTile(BuildContext context, Map<String, dynamic> chatRoomData) {
    final lastMessage = chatRoomData['lastMessage'] ?? '';
    final lastMessageTime = chatRoomData['lastMessageTime'] as Timestamp?;
    final groupOrderId = chatRoomData['group_id'] ?? chatRoomData['groupOrderId'] ?? '';
    final participants = chatRoomData['participants'] as List<dynamic>? ?? [];
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[200],
        child: Icon(
          Icons.group,
          color: Colors.green[700],
        ),
      ),
      title: Text(
        'Order $groupOrderId',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            '${participants.length} participants',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: lastMessageTime != null
          ? Text(
              TimerUtilsService.formatTimestamp(lastMessageTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatRoomId: chatRoomData['id'], // Use the document ID, not the nested chatRoomId field
              groupOrderId: groupOrderId,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
    );
  }
}
