import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimerUtilsService {
  /// Build a countdown timer widget for scheduled deliveries
  static Widget buildCountdownTimer(dynamic scheduledTime) {
    if (scheduledTime == null) return const SizedBox.shrink();
    
    try {
      DateTime targetTime;
      if (scheduledTime is Timestamp) {
        targetTime = scheduledTime.toDate();
      } else if (scheduledTime is DateTime) {
        targetTime = scheduledTime;
      } else {
        return const SizedBox.shrink();
      }

      return StreamBuilder<DateTime>(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
        builder: (context, snapshot) {
          final now = DateTime.now();
          final difference = targetTime.difference(now);
          
          if (difference.isNegative) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          
          final hours = difference.inHours;
          final minutes = difference.inMinutes % 60;
          final seconds = difference.inSeconds % 60;
          
          Color timerColor = Colors.green;
          if (hours == 0 && minutes < 30) {
            timerColor = Colors.red;
          } else if (hours == 0 && minutes < 60) {
            timerColor = Colors.orange;
          }
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: timerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hours > 0 
                  ? '${hours}h ${minutes}m'
                  : '${minutes}m ${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// Format timestamp for display
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Invalid date';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Check if an order is ready for delivery (within 30 minutes of scheduled time)
  static bool isOrderReadyForDelivery(dynamic scheduledTime) {
    if (scheduledTime == null) return true; // If no scheduled time, allow immediately
    
    final now = DateTime.now();
    late DateTime scheduledDateTime;
    
    if (scheduledTime is Timestamp) {
      scheduledDateTime = scheduledTime.toDate();
    } else if (scheduledTime is DateTime) {
      scheduledDateTime = scheduledTime;
    } else {
      return true; // Invalid type, allow delivery
    }
    
    final timeDifference = scheduledDateTime.difference(now);
    
    // Allow delivery if within 30 minutes of scheduled time
    return timeDifference.inMinutes <= 30;
  }

  /// Get time remaining until order is ready for delivery
  static String getTimeUntilReady(dynamic scheduledTime) {
    if (scheduledTime == null) return '';
    
    final now = DateTime.now();
    late DateTime scheduledDateTime;
    
    if (scheduledTime is Timestamp) {
      scheduledDateTime = scheduledTime.toDate();
    } else if (scheduledTime is DateTime) {
      scheduledDateTime = scheduledTime;
    } else {
      return '';
    }
    
    final timeDifference = scheduledDateTime.difference(now);
    
    if (timeDifference.inMinutes <= 30) return 'Ready for delivery';
    
    final hours = timeDifference.inHours;
    final minutes = timeDifference.inMinutes % 60;
    
    if (hours > 0) {
      return 'Ready in ${hours}h ${minutes}m';
    } else {
      return 'Ready in ${minutes}m';
    }
  }

  /// Check if an order is overdue
  static bool isOrderOverdue(dynamic scheduledTime) {
    if (scheduledTime == null) return false;
    
    late DateTime scheduledDateTime;
    
    if (scheduledTime is Timestamp) {
      scheduledDateTime = scheduledTime.toDate();
    } else if (scheduledTime is DateTime) {
      scheduledDateTime = scheduledTime;
    } else {
      return false;
    }
    
    return DateTime.now().isAfter(scheduledDateTime);
  }

  /// Get time remaining until scheduled time
  static Duration? getTimeRemaining(dynamic scheduledTime) {
    if (scheduledTime == null) return null;
    
    late DateTime scheduledDateTime;
    
    if (scheduledTime is Timestamp) {
      scheduledDateTime = scheduledTime.toDate();
    } else if (scheduledTime is DateTime) {
      scheduledDateTime = scheduledTime;
    } else {
      return null;
    }
    
    final difference = scheduledDateTime.difference(DateTime.now());
    return difference.isNegative ? null : difference;
  }
}
