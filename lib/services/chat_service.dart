import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a chat room for a group order with driver, vendor, and customers
  static Future<String?> createOrderChatRoom({
    required String groupOrderId,
    required String driverId,
    required String vendorId,
    required List<String> customerIds,
  }) async {
    try {
      print('🔄 Creating chat room for order: $groupOrderId');
      print('📝 Driver: $driverId, Vendor: $vendorId, Customers: $customerIds');
      
      final chatRoomId = FirebaseFirestore.instance.collection('chatroom').doc().id;
      
      // Combine all participants
      final participants = <String>[];
      participants.add(driverId);
      if (vendorId.isNotEmpty) participants.add(vendorId);
      participants.addAll(customerIds);
      
      // Remove duplicates
      final uniqueParticipants = participants.toSet().toList();
      
      print('👥 Unique participants: $uniqueParticipants');

      final chatRoomData = {
        'chatRoomId': chatRoomId,
        'group_id': groupOrderId,
        'participants': uniqueParticipants,
        'lastMessage': 'Delivery chat created',
        'lastMessageTime': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'isGroup': true,
        'status': 'active',
      };

      await _firestore.collection('chatroom').doc(chatRoomId).set(chatRoomData);
      print('✅ Chat room created with ID: $chatRoomId');
      
      // Send initial system message with QR codes
      await _sendInitialSystemMessageWithQrCodes(chatRoomId, groupOrderId, driverId, vendorId);
      print('✅ Initial system message with QR codes sent');
      
      return chatRoomId;
    } catch (e) {
      print('❌ Error creating order chat room: $e');
      return null;
    }
  }

  /// Marks chat room as completed and schedules it for deactivation after 24 hours
  static Future<void> completeOrderChatRoom(String groupOrderId) async {
    try {
      // Find chat room by group_id instead of using fixed naming convention
      final chatRooms = await _firestore
          .collection('chatroom')
          .where('group_id', isEqualTo: groupOrderId)
          .where('status', isEqualTo: 'active')
          .get();
      
      for (var doc in chatRooms.docs) {
        final chatRoomData = doc.data();
        
        await doc.reference.update({
          'status': 'completed',
          'completedAt': Timestamp.now(),
          'lastMessage': 'Order completed. Chat will be disabled after 24 hours.',
          'lastMessageTime': Timestamp.now(),
        });
        
        // Send system message about completion with QR codes for final reference
        await _sendCompletionSystemMessageWithQrCodes(doc.id, groupOrderId, chatRoomData);
      }
      
    } catch (e) {
      print('Error completing chat room: $e');
    }
  }

  /// Deactivates chat rooms that have been completed for more than 24 hours
  static Future<void> deactivateExpiredChatRooms() async {
    try {
      final now = Timestamp.now();
      final twentyFourHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24))
      );

      final expiredChatRooms = await _firestore
          .collection('chatroom')
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isLessThan: twentyFourHoursAgo)
          .get();

      final batch = _firestore.batch();

      for (var doc in expiredChatRooms.docs) {
        batch.update(doc.reference, {
          'status': 'inactive',
          'deactivatedAt': now,
        });
      }

      await batch.commit();
      print('Deactivated ${expiredChatRooms.docs.length} expired chat rooms');
    } catch (e) {
      print('Error deactivating expired chat rooms: $e');
    }
  }

  static Future<void> _sendSystemMessage(String chatRoomId, String message) async {
    try {
      await _firestore.collection('chatmessages').add({
        'chatRoomId': chatRoomId,
        'senderId': 'system',
        'senderName': 'System',
        'text': message,
        'type': 'system',
        'sentAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  /// Sends initial system message with driver and vendor QR codes
  static Future<void> _sendInitialSystemMessageWithQrCodes(
    String chatRoomId, 
    String groupOrderId, 
    String driverId, 
    String vendorId
  ) async {
    try {
      // Get driver QR code
      String driverInfo = '🚚 Driver ID: $driverId';
      try {
        final driverDoc = await _firestore.collection('users').doc(driverId).get();
        if (driverDoc.exists) {
          final driverData = driverDoc.data()!;
          final driverName = driverData['name'] ?? 'Unknown Driver';
          final driverQrCode = driverData['qr_code'];
          
          driverInfo = '🚚 Driver: $driverName';
          if (driverQrCode != null && driverQrCode.isNotEmpty) {
            driverInfo += '\n📱 Driver QR Code: $driverQrCode';
          }
        }
      } catch (e) {
        print('Error fetching driver info: $e');
      }

      // Get vendor QR code
      String vendorInfo = '🏪 Vendor ID: $vendorId';
      if (vendorId.isNotEmpty) {
        try {
          final vendorDoc = await _firestore.collection('users').doc(vendorId).get();
          if (vendorDoc.exists) {
            final vendorData = vendorDoc.data()!;
            final vendorName = vendorData['name'] ?? 'Unknown Vendor';
            final vendorQrCode = vendorData['qr_code'];
            
            vendorInfo = '🏪 Vendor: $vendorName';
            if (vendorQrCode != null && vendorQrCode.isNotEmpty) {
              vendorInfo += '\n💳 Vendor Payment QR: $vendorQrCode';
            }
          }
        } catch (e) {
          print('Error fetching vendor info: $e');
        }
      }

      // Compose the full system message
      final systemMessage = '''🚛 Delivery Chat Started for Order #$groupOrderId

$driverInfo

$vendorInfo

💬 All participants can communicate here for delivery coordination.
📞 Use QR codes for verification and payments.''';

      // Send the enhanced system message
      await _firestore.collection('chatmessages').add({
        'chatRoomId': chatRoomId,
        'senderId': 'system',
        'senderName': 'System',
        'text': systemMessage,
        'type': 'system',
        'sentAt': Timestamp.now(),
      });

    } catch (e) {
      print('Error sending initial system message with QR codes: $e');
      // Fallback to basic message
      await _sendSystemMessage(chatRoomId, 'Delivery chat started for order $groupOrderId. Driver, vendor, and customers can communicate here.');
    }
  }

  /// Sends completion system message with QR codes for final reference
  static Future<void> _sendCompletionSystemMessageWithQrCodes(
    String chatRoomId, 
    String groupOrderId, 
    Map<String, dynamic> chatRoomData
  ) async {
    try {
      final participants = List<String>.from(chatRoomData['participants'] ?? []);
      
      // Find driver and vendor from participants
      String? driverId;
      String? vendorId;
      
      for (String participantId in participants) {
        try {
          final userDoc = await _firestore.collection('users').doc(participantId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final role = userData['role']?.toLowerCase();
            
            if (role == 'driver' || role == 'runner') {
              driverId = participantId;
            } else if (role == 'vendor') {
              vendorId = participantId;
            }
          }
        } catch (e) {
          print('Error checking participant role: $e');
        }
      }

      // Build completion message with QR codes
      String completionMessage = '✅ Order #$groupOrderId has been completed!\n\n';
      
      // Add driver QR if available
      if (driverId != null) {
        try {
          final driverDoc = await _firestore.collection('users').doc(driverId).get();
          if (driverDoc.exists) {
            final driverData = driverDoc.data()!;
            final driverName = driverData['name'] ?? 'Unknown Driver';
            final driverQrCode = driverData['qr_code'];
            
            completionMessage += '🚚 Driver: $driverName\n';
            if (driverQrCode != null && driverQrCode.isNotEmpty) {
              completionMessage += '📱 Driver QR: $driverQrCode\n';
            }
          }
        } catch (e) {
          print('Error fetching driver completion info: $e');
        }
      }

      // Add vendor QR if available
      if (vendorId != null) {
        try {
          final vendorDoc = await _firestore.collection('users').doc(vendorId).get();
          if (vendorDoc.exists) {
            final vendorData = vendorDoc.data()!;
            final vendorName = vendorData['name'] ?? 'Unknown Vendor';
            final vendorQrCode = vendorData['qr_code'];
            
            completionMessage += '\n🏪 Vendor: $vendorName\n';
            if (vendorQrCode != null && vendorQrCode.isNotEmpty) {
              completionMessage += '💳 Payment QR: $vendorQrCode\n';
            }
          }
        } catch (e) {
          print('Error fetching vendor completion info: $e');
        }
      }

      completionMessage += '\n💬 This chat will be automatically disabled after 24 hours.\n🙏 Thank you for using MealMommy!';

      // Send the completion message
      await _firestore.collection('chatmessages').add({
        'chatRoomId': chatRoomId,
        'senderId': 'system',
        'senderName': 'System',
        'text': completionMessage,
        'type': 'system',
        'sentAt': Timestamp.now(),
      });

    } catch (e) {
      print('Error sending completion message with QR codes: $e');
      // Fallback to basic completion message
      await _sendSystemMessage(chatRoomId, 'Order has been completed! This chat will be automatically disabled after 24 hours.');
    }
  }

  /// Gets active chat room for a group order
  static Future<String?> getChatRoomForOrder(String groupOrderId) async {
    try {
      final chatRooms = await _firestore
          .collection('chatroom')
          .where('group_id', isEqualTo: groupOrderId)
          .where('status', whereIn: ['active', 'completed'])
          .get();
      
      if (chatRooms.docs.isNotEmpty) {
        return chatRooms.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error getting chat room for order: $e');
      return null;
    }
  }

  /// Gets all active chat rooms for a user
  static Future<List<Map<String, dynamic>>> getUserChatRooms(String userId) async {
    try {
      // Simplified query to avoid complex index requirement
      final userChatRooms = await _firestore
          .collection('chatroom')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'active')
          .get();

      // Sort manually by lastMessageTime
      final chatRoomList = userChatRooms.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      
      // Sort by lastMessageTime descending
      chatRoomList.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp?;
        final bTime = b['lastMessageTime'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime);
      });

      return chatRoomList;
    } catch (e) {
      print('Error getting user chat rooms: $e');
      return [];
    }
  }

  /// Checks if user has any unread messages in active chat rooms
  static Future<bool> hasUnreadMessages(String userId) async {
    try {
      // Simplified query - just get user's chat rooms first
      final userChatRooms = await _firestore
          .collection('chatroom')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatRoom in userChatRooms.docs) {
        final chatRoomData = chatRoom.data();
        final status = chatRoomData['status'];
        
        // Only check active and completed chat rooms
        if (status == 'active' || status == 'completed') {
          final lastMessageTime = chatRoomData['lastMessageTime'] as Timestamp?;
          
          if (lastMessageTime != null) {
            // Check if there are recent messages (within last hour)
            final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
            if (lastMessageTime.toDate().isAfter(oneHourAgo)) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking unread messages: $e');
      return false;
    }
  }
}
