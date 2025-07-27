class DeliveryPreferences {
  final String id; // Document ID (usually same as driver's uid)
  final String driverId; // Reference to the driver's uid
  final bool active;
  final int maxDistance;
  final String runnerId;
  final String transportMode;


  DeliveryPreferences({
    required this.id,
    required this.driverId,
    required this.active,
    required this.maxDistance,
    required this.runnerId,
    required this.transportMode,

  });

  /// Factory constructor to build a DeliveryPreferences object from Firestore data
  factory DeliveryPreferences.fromFirestore(Map<String, dynamic> data, String id) {
    return DeliveryPreferences(
      id: id,
      driverId: data['driver_id'] ?? '',
      active: data['active'] ?? false,
      maxDistance: data['max_distance'] ?? 7,
      runnerId: data['runnerid'] ?? '',
      transportMode: data['transport_mode'] ?? 'car',

    );
  }

  /// Create default preferences for new drivers
  factory DeliveryPreferences.createDefault({
    required String driverId,
    String? runnerId,
  }) {
    return DeliveryPreferences(
      id: driverId, // Use driver's uid as document ID
      driverId: driverId,
      active: false, // Start inactive by default
      maxDistance: 7, // Default 7km radius
      runnerId: runnerId ?? driverId, // Use driver's uid if no runner ID provided
      transportMode: 'car', // Default transport mode

    );
  }

  /// Convert DeliveryPreferences to Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'driver_id': driverId,
      'active': active,
      'max_distance': maxDistance,
      'runnerid': runnerId,
      'transport_mode': transportMode
    };
  }

  /// Create a copy with updated values
  DeliveryPreferences copyWith({
    String? id,
    String? driverId,
    bool? active,
    int? maxDistance,
    String? runnerId,
    String? transportMode
  }) {
    return DeliveryPreferences(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      active: active ?? this.active,
      maxDistance: maxDistance ?? this.maxDistance,
      runnerId: runnerId ?? this.runnerId,
      transportMode: transportMode ?? this.transportMode
    );
  }

  @override
  String toString() {
    return 'DeliveryPreferences(id: $id, driverId: $driverId, active: $active, maxDistance: $maxDistance, runnerId: $runnerId, transportMode: $transportMode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryPreferences && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
