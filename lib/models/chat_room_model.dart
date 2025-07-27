import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String chatRoomId;
  final String? groupId;
  final List<String> participants;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final Timestamp createdAt;
  final bool isGroup;
  final String status;

  ChatRoom({
    required this.id,
    required this.chatRoomId,
    this.groupId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.createdAt,
    required this.isGroup,
    required this.status,
  });

  factory ChatRoom.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatRoom(
      id: id,
      chatRoomId: data['chatRoomId'] ?? id,
      groupId: data['group_id'],
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isGroup: data['isGroup'] ?? true,
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'group_id': groupId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'createdAt': createdAt,
      'isGroup': isGroup,
      'status': status,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? chatRoomId,
    String? groupId,
    List<String>? participants,
    String? lastMessage,
    Timestamp? lastMessageTime,
    Timestamp? createdAt,
    bool? isGroup,
    String? status,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      groupId: groupId ?? this.groupId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt ?? this.createdAt,
      isGroup: isGroup ?? this.isGroup,
      status: status ?? this.status,
    );
  }
}
