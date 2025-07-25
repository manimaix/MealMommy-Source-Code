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
}
