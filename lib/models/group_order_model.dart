import 'package:cloud_firestore/cloud_firestore.dart';

class GroupOrder {
  final String id;
  final String vendorId;
  final String? driverId;
  final String status;
  final Timestamp? assignedAt;
  final Timestamp? completedAt;
  final int? currentDeliveryIndex;
  final int? currentNavigationStep;
  final Timestamp? scheduledTime;
  final Timestamp updatedAt;

  GroupOrder({
    required this.id,
    required this.vendorId,
    this.driverId,
    required this.status,
    this.assignedAt,
    this.completedAt,
    this.currentDeliveryIndex,
    this.currentNavigationStep,
    this.scheduledTime,
    required this.updatedAt,
  });

  factory GroupOrder.fromFirestore(Map<String, dynamic> data, String id) {
    return GroupOrder(
      id: id,
      vendorId: data['vendor_id'] ?? '',
      driverId: data['driver_id'],
      status: data['status'] ?? 'pending',
      assignedAt: data['assigned_at'],
      completedAt: data['completed_at'],
      currentDeliveryIndex: data['current_delivery_index'],
      currentNavigationStep: data['current_navigation_step'],
      scheduledTime: data['scheduled_time'],
      updatedAt: data['updated_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'driver_id': driverId,
      'status': status,
      'assigned_at': assignedAt,
      'completed_at': completedAt,
      'current_delivery_index': currentDeliveryIndex,
      'current_navigation_step': currentNavigationStep,
      'scheduled_time': scheduledTime,
      'updated_at': updatedAt,
    };
  }

  GroupOrder copyWith({
    String? id,
    String? vendorId,
    String? driverId,
    String? status,
    Timestamp? assignedAt,
    Timestamp? completedAt,
    int? currentDeliveryIndex,
    int? currentNavigationStep,
    Timestamp? scheduledTime,
    Timestamp? updatedAt,
  }) {
    return GroupOrder(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      currentDeliveryIndex: currentDeliveryIndex ?? this.currentDeliveryIndex,
      currentNavigationStep: currentNavigationStep ?? this.currentNavigationStep,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  bool get isAssigned => driverId != null && driverId!.isNotEmpty;
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isInProgress => status.toLowerCase() == 'in_progress';
  
  // Check if order is overdue
  bool get isOverdue {
    if (scheduledTime == null) return false;
    return DateTime.now().isAfter(scheduledTime!.toDate());
  }
  
  // Get time remaining until scheduled time
  Duration? get timeRemaining {
    if (scheduledTime == null) return null;
    final now = DateTime.now();
    final scheduled = scheduledTime!.toDate();
    return scheduled.isAfter(now) ? scheduled.difference(now) : null;
  }
  
  // Check if order is urgent (less than 30 minutes)
  bool get isUrgent {
    final remaining = timeRemaining;
    if (remaining == null) return isOverdue;
    return remaining.inMinutes < 30;
  }
  
  // Get formatted time remaining
  String get formattedTimeRemaining {
    if (isOverdue) return 'OVERDUE';
    final remaining = timeRemaining;
    if (remaining == null) return 'N/A';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
