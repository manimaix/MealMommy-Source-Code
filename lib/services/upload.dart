import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> uploadToFirebaseStorage(File imageFile) async {
  try {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance.ref().child('meal_images/$fileName');

    // Upload file
    await storageRef.putFile(imageFile);

    // Get download URL
    final downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    print("Firebase upload error: $e");
    return null;
  }
}
