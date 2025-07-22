import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static Future<dynamic> getField({
    required String collection,
    required String docId,
    required String field,
  }) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc[field];
      } else {
        return 'Document or field not found';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
