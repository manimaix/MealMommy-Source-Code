import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<AppUser?> get userStream {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      return await _getUserData(user.uid);
    });
  }

  // Get current user
  AppUser? get currentUser {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    // Note: This returns a basic user, for full data use getCurrentUserData()
    return AppUser.fromFirebaseUser(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'User',
      phoneNumber: '', // Will be loaded from Firestore
      address: '', // Will be loaded from Firestore
      profileImage: user.photoURL,
      role: 'customer', // Default role
    );
  }

  // Get current user data from Firestore
  Future<AppUser?> getCurrentUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    return await _getUserData(user.uid);
  }

  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) return null;

      // Get FCM token and save after sign-in
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
         print('FCM Token for this device: $token');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcm_token': token,
        }, SetOptions(merge: true));
      }

      // Get user data from Firestore
      AppUser? userData = await _getUserData(result.user!.uid);
      
      // If no user document exists (old account), create a default customer account
      if (userData == null) {
        print('AuthService: No user document found for existing user, creating default customer');
        final AppUser newUser = AppUser.fromFirebaseUser(
          uid: result.user!.uid,
          email: result.user!.email ?? '',
          name: result.user!.displayName ?? 'User',
          phoneNumber: '', // Default empty, user can update later
          address: '', // Default empty, user can update later
          profileImage: result.user!.photoURL,
          role: 'customer', // Default role for existing accounts
        );
        await _createUserDocument(newUser);
        userData = newUser;
      }
      
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign in: ${e.toString()}');
    }
  }

  // Create user with email and password
  Future<AppUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required String address,
    String? profileImage,
    String role = 'customer',
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) return null;

      // Update display name
      await result.user!.updateDisplayName(name);

      // Create user document in Firestore
      final AppUser newUser = AppUser.fromFirebaseUser(
        uid: result.user!.uid,
        email: email,
        name: name,
        phoneNumber: phoneNumber,
        address: address,
        profileImage: profileImage ?? result.user!.photoURL,
        role: role,
      );

      print('AuthService: Creating user with role: $role');
      await _createUserDocument(newUser);
      print('AuthService: User document created successfully');
      
      // Small delay to ensure Firestore document is saved
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Fetch the user data again to ensure proper role detection
      final fetchedUser = await _getUserData(result.user!.uid);
      print('AuthService: Fetched user after creation with role: ${fetchedUser?.role}');
      return fetchedUser ?? newUser; // Fallback to newUser if fetch fails
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during registration: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error sending password reset email: ${e.toString()}');
    }
  }

  // Update user profile
  Future<AppUser?> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? address,
    String? profileImage,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in');

      // Update Firebase Auth profile
      if (name != null) await user.updateDisplayName(name);
      if (profileImage != null) await user.updatePhotoURL(profileImage);

      // Update Firestore document
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (address != null) updates['address'] = address;
      if (profileImage != null) updates['profile_image'] = profileImage;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }

      return await _getUserData(user.uid);
    } catch (e) {
      throw Exception('Error updating profile: ${e.toString()}');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Private helper methods

  // Get user data from Firestore
  Future<AppUser?> _getUserData(String uid) async {
    try {
      print('AuthService: Getting user data for UID: $uid');
      final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) {
        print('AuthService: User document does not exist');
        // Only create a fallback user during sign-in, not during registration
        // This prevents overriding newly created accounts with wrong roles
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final user = AppUser.fromJson(data);
      print('AuthService: Retrieved user with role: ${user.role}');
      return user;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(AppUser user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toJson());
    } catch (e) {
      print('Error creating user document: $e');
      throw Exception('Failed to create user profile');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'The supplied auth credential is incorrect, malformed or has expired.';
      default:
        return 'Authentication error: ${e.message ?? 'Unknown error'}';
    }
  }
}
