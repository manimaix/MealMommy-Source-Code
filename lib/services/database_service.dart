import 'package:cloud_firestore/cloud_firestore.dart';

/// A reusable service class for interacting with Cloud Firestore.
class FirebaseService {
  // Singleton instance
  static final FirebaseService instance = FirebaseService._internal();

  // Private constructor
  FirebaseService._internal();

  /// Fetches all documents from the specified [collectionName] and
  /// Returns a [List] of [Map<String, dynamic>] representing each document's data.
  Future<List<Map<String, dynamic>>> fetchAllDocuments(String collectionName) async {
    final querySnapshot = await FirebaseFirestore.instance.collection(collectionName).get();
    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Adds a document with [data] to the specified [collectionName].
  /// Returns the [DocumentReference] of the newly added document.
  Future<DocumentReference> addDocument(String collectionName, Map<String, dynamic> data) async {
    return await FirebaseFirestore.instance.collection(collectionName).add(data);
  }

  Future<List<Map<String, dynamic>>> fetchUserNotifications({
  required String receiverId,
  int limit = 2,
  }) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('notification')
        .where('receiver_id', isEqualTo: receiverId)
        .orderBy('sent_at', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
}
