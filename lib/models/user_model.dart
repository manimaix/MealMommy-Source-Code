class AppUser {
  final String uid; // Document ID (e.g., U0001)
  final String email;
  final String name;
  
  final String phoneNumber;
  final String address;
  final String? profileImage;
  final String role; // "customer" or "vendor" or "driver"
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,

    required this.phoneNumber,
    required this.address,
    this.profileImage,
    required this.role,
    required this.createdAt,
  });

  // Create AppUser from Firebase User and additional data
  factory AppUser.fromFirebaseUser({
    required String uid,
    required String email,
    required String name,
    required String phoneNumber,
    required String address,
    String? profileImage,
    required String role,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name,
      phoneNumber: phoneNumber,
      address: address,
      profileImage: profileImage,
      role: role,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'profile_image': profileImage,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      profileImage: json['profile_image'],
      role: json['role'] ?? 'customer',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? phoneNumber,
    String? address,
    String? profileImage,
    String? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, name: $name, phoneNumber: $phoneNumber, address: $address, profileImage: $profileImage, role: $role, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
