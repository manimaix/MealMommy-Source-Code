import '../models/models.dart';

class RevenueService {
  
  /// Calculate revenue from completed group orders and individual orders
  static Map<String, dynamic> calculateRevenue({
    required List<GroupOrder> allGroupOrders,
    required List<Order> allOrders,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisYear = DateTime(now.year, 1, 1);

    // Initialize counters
    double todayRevenue = 0.0;
    double monthRevenue = 0.0;
    double yearRevenue = 0.0;
    double totalRevenue = 0.0;
    
    int todayOrders = 0;
    int monthOrders = 0;
    int yearOrders = 0;
    int totalOrders = 0;

    // Calculate revenue from completed group orders only
    final completedGroupOrders = allGroupOrders.where((group) => group.status == 'completed').toList();

    for (var groupOrder in completedGroupOrders) {
      // Use completed_at timestamp if available, otherwise fall back to updated_at
      final completionDate = groupOrder.completedAt?.toDate() ?? groupOrder.updatedAt.toDate();

      // Find all orders that belong to this completed group order
      final groupOrdersInList = allOrders.where((order) => order.groupId == groupOrder.id).toList();
      
      // Calculate total delivery fees for this group order
      double groupRevenue = 0.0;
      for (var order in groupOrdersInList) {
        final fee = order.deliveryFeeAsDouble;
        groupRevenue += fee;
      }

      // Only add to totals if this group has revenue
      if (groupRevenue > 0) {
        totalRevenue += groupRevenue;
        totalOrders++;

        if (completionDate.isAfter(today) || completionDate.isAtSameMomentAs(today)) {
          todayRevenue += groupRevenue;
          todayOrders++;
        }

        if (completionDate.isAfter(thisMonth) || completionDate.isAtSameMomentAs(thisMonth)) {
          monthRevenue += groupRevenue;
          monthOrders++;
        }

        if (completionDate.isAfter(thisYear) || completionDate.isAtSameMomentAs(thisYear)) {
          yearRevenue += groupRevenue;
          yearOrders++;
        }
      }
    }

    return {
      'todayRevenue': todayRevenue,
      'monthRevenue': monthRevenue,
      'yearRevenue': yearRevenue,
      'totalRevenue': totalRevenue,
      'todayOrders': todayOrders,
      'monthOrders': monthOrders,
      'yearOrders': yearOrders,
      'totalOrders': totalOrders,
    };
  }

  /// Filter group orders by time period
  static List<GroupOrder> getFilteredGroupOrders({
    required List<GroupOrder> allGroupOrders,
    required String selectedPeriod,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisYear = DateTime(now.year, 1, 1);

    return allGroupOrders.where((groupOrder) {
      // Only show completed group orders
      if (groupOrder.status != 'completed') return false;
      
      final completionDate = groupOrder.completedAt?.toDate() ?? groupOrder.updatedAt.toDate();
      
      switch (selectedPeriod) {
        case 'today':
          return completionDate.isAfter(today) || completionDate.isAtSameMomentAs(today);
        case 'month':
          return completionDate.isAfter(thisMonth) || completionDate.isAtSameMomentAs(thisMonth);
        case 'year':
          return completionDate.isAfter(thisYear) || completionDate.isAtSameMomentAs(thisYear);
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  /// Get filtered revenue based on period
  static double getFilteredRevenue({
    required String selectedPeriod,
    required Map<String, dynamic> revenueData,
  }) {
    switch (selectedPeriod) {
      case 'today':
        return revenueData['todayRevenue'] ?? 0.0;
      case 'month':
        return revenueData['monthRevenue'] ?? 0.0;
      case 'year':
        return revenueData['yearRevenue'] ?? 0.0;
      case 'all':
      default:
        return revenueData['totalRevenue'] ?? 0.0;
    }
  }

  /// Get filtered order count based on period
  static int getFilteredOrderCount({
    required String selectedPeriod,
    required Map<String, dynamic> revenueData,
  }) {
    switch (selectedPeriod) {
      case 'today':
        return revenueData['todayOrders'] ?? 0;
      case 'month':
        return revenueData['monthOrders'] ?? 0;
      case 'year':
        return revenueData['yearOrders'] ?? 0;
      case 'all':
      default:
        return revenueData['totalOrders'] ?? 0;
    }
  }
}