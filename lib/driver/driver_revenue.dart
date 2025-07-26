import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverRevenuePage extends StatefulWidget {
  const DriverRevenuePage({super.key});

  @override
  State<DriverRevenuePage> createState() => _DriverRevenuePageState();
}

class _DriverRevenuePageState extends State<DriverRevenuePage>
    with TickerProviderStateMixin {
  AppUser? currentUser;
  List<Order> allOrders = [];
  List<GroupOrder> allGroupOrders = [];
  bool isLoading = true;
  String selectedPeriod = 'today';
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Revenue data
  double todayRevenue = 0.0;
  double monthRevenue = 0.0;
  double yearRevenue = 0.0;
  double totalRevenue = 0.0;
  
  // Order counts
  int todayOrders = 0;
  int monthOrders = 0;
  int yearOrders = 0;
  int totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _loadDriverData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user from Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('No current user found');
      }

      // Get user details from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        currentUser = AppUser.fromJson(userDoc.data()!);
      } else {
        throw Exception('User data not found');
      }

      // Load group orders first, then individual orders
      await _loadAllGroupOrders();
      await _loadAllOrders();
      _calculateRevenue();
      
      // Start fade animation
      _fadeController.forward();
    } catch (e) {
      print('Error loading driver data: $e');
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAllOrders() async {
    if (currentUser == null) return;

    try {
      // Get individual orders for ALL group orders (not just completed ones)
      // We'll filter by completion status during revenue calculation
      allOrders = [];
      
      print('🔍 Loading orders for ${allGroupOrders.length} group orders');
      
      for (var groupOrder in allGroupOrders) {
        print('📦 Loading orders for group order ${groupOrder.id} with status: ${groupOrder.status}');
        
        try {
          print('🔍 Querying orders for group_id: ${groupOrder.id}');
          final ordersSnapshot = await FirebaseFirestore.instance
              .collection('orders')
              .where('group_id', isEqualTo: groupOrder.id)
              .get();

          print('📄 Found ${ordersSnapshot.docs.length} orders for group ${groupOrder.id}');
          
          final groupOrdersList = ordersSnapshot.docs
              .map((doc) {
                print('📋 Order data: ${doc.data()}');
                return Order.fromFirestore(doc.data(), doc.id);
              })
              .toList();
              
          allOrders.addAll(groupOrdersList);
          print('➕ Added ${groupOrdersList.length} orders to allOrders');
        } catch (e) {
          print('❌ Error loading orders for group ${groupOrder.id}: $e');
        }
      }
          
      print('✅ Loaded ${allOrders.length} total orders from ${allGroupOrders.length} group orders for driver ${currentUser!.uid}');
      
      // Show breakdown by group status
      final completedGroups = allGroupOrders.where((g) => g.status == 'completed').length;
      final ordersFromCompleted = allOrders.where((order) => 
        allGroupOrders.any((group) => group.id == order.groupId && group.status == 'completed')
      ).length;
      
      print('📊 Orders breakdown: $ordersFromCompleted orders from $completedGroups completed groups');
    } catch (e) {
      print('❌ Error loading orders: $e');
      allOrders = [];
    }
  }

  Future<void> _loadAllGroupOrders() async {
    if (currentUser == null) return;

    try {
      print('🔍 Loading group orders for driver: ${currentUser!.uid}');
      
      // Get all group orders for this driver using runner_id first (without orderBy to avoid index requirement)
      final groupOrdersSnapshot = await FirebaseFirestore.instance
          .collection('grouporders')
          .where('driver_id', isEqualTo: currentUser!.uid)
          .get();

      allGroupOrders = groupOrdersSnapshot.docs
          .map((doc) {
            print('📦 Group order data: ${doc.data()}');
            return GroupOrder.fromFirestore(doc.data(), doc.id);
          })
          .toList();
          
      print('✅ Loaded ${allGroupOrders.length} group orders for driver ${currentUser!.uid}');
      
      // Print status breakdown
      final statusCounts = <String, int>{};
      for (var order in allGroupOrders) {
        statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
      }
      print('📊 Group order status breakdown: $statusCounts');
      
    } catch (e) {
      print('❌ Error loading group orders with runner_id: $e');
      // Try alternative query if the first one fails (fallback to driver_id)
      try {
        print('🔄 Trying fallback query with driver_id');
        final fallbackSnapshot = await FirebaseFirestore.instance
            .collection('grouporders')
            .where('driver_id', isEqualTo: currentUser!.uid)
            .get();

        allGroupOrders = fallbackSnapshot.docs
            .map((doc) {
              print('📦 Fallback group order data: ${doc.data()}');
              return GroupOrder.fromFirestore(doc.data(), doc.id);
            })
            .toList();
            
        print('✅ Loaded ${allGroupOrders.length} group orders using fallback driver_id query');
        
        // Print status breakdown for fallback
        final statusCounts = <String, int>{};
        for (var order in allGroupOrders) {
          statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
        }
        print('📊 Fallback group order status breakdown: $statusCounts');
        
      } catch (fallbackError) {
        print('❌ Fallback group orders query also failed: $fallbackError');
        allGroupOrders = [];
      }
    }
  }

  void _calculateRevenue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisYear = DateTime(now.year, 1, 1);

    // Reset counters
    todayRevenue = 0.0;
    monthRevenue = 0.0;
    yearRevenue = 0.0;
    totalRevenue = 0.0;
    
    todayOrders = 0;
    monthOrders = 0;
    yearOrders = 0;
    totalOrders = 0;

    print('🔍 Calculating revenue from ${allGroupOrders.length} group orders');
    print('🔍 Total individual orders loaded: ${allOrders.length}');

    // Calculate revenue from completed group orders only
    final completedGroupOrders = allGroupOrders.where((group) => group.status == 'completed').toList();
    print('🎯 Processing ${completedGroupOrders.length} completed group orders');

    for (var groupOrder in completedGroupOrders) {
      print('📦 Processing completed group order ${groupOrder.id}');
      
      // Use completed_at timestamp if available, otherwise fall back to updated_at
      final completionDate = groupOrder.completedAt?.toDate() ?? groupOrder.updatedAt.toDate();
      print('📅 Completion date for ${groupOrder.id}: $completionDate');

      // Find all orders that belong to this completed group order
      final groupOrdersInList = allOrders.where((order) => order.groupId == groupOrder.id).toList();
      print('🔗 Found ${groupOrdersInList.length} orders for completed group ${groupOrder.id}');
      
      // Calculate total delivery fees for this group order
      double groupRevenue = 0.0;
      for (var order in groupOrdersInList) {
        final fee = order.deliveryFeeAsDouble;
        print('💰 Order ${order.id}: delivery_fee = "${order.deliveryFee}" -> RM$fee');
        groupRevenue += fee;
      }

      print('💵 Total revenue for group ${groupOrder.id}: RM$groupRevenue');

      // Only add to totals if this group has revenue
      if (groupRevenue > 0) {
        totalRevenue += groupRevenue;
        totalOrders++;

        if (completionDate.isAfter(today) || completionDate.isAtSameMomentAs(today)) {
          todayRevenue += groupRevenue;
          todayOrders++;
          print('📊 Added RM$groupRevenue to today\'s revenue');
        }

        if (completionDate.isAfter(thisMonth) || completionDate.isAtSameMomentAs(thisMonth)) {
          monthRevenue += groupRevenue;
          monthOrders++;
          print('📊 Added RM$groupRevenue to month\'s revenue');
        }

        if (completionDate.isAfter(thisYear) || completionDate.isAtSameMomentAs(thisYear)) {
          yearRevenue += groupRevenue;
          yearOrders++;
          print('📊 Added RM$groupRevenue to year\'s revenue');
        }
      } else {
        print('⚠️ Group ${groupOrder.id} has no revenue (no orders or zero fees)');
      }
    }

    print('🎯 Final revenue calculation:');
    print('   Today: RM$todayRevenue ($todayOrders orders)');
    print('   Month: RM$monthRevenue ($monthOrders orders)');
    print('   Year: RM$yearRevenue ($yearOrders orders)');
    print('   Total: RM$totalRevenue ($totalOrders orders)');
  }

  List<GroupOrder> _getFilteredGroupOrders() {
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

  double _getFilteredRevenue() {
    switch (selectedPeriod) {
      case 'today':
        return todayRevenue;
      case 'month':
        return monthRevenue;
      case 'year':
        return yearRevenue;
      case 'all':
      default:
        return totalRevenue;
    }
  }

  int _getFilteredOrderCount() {
    switch (selectedPeriod) {
      case 'today':
        return todayOrders;
      case 'month':
        return monthOrders;
      case 'year':
        return yearOrders;
      case 'all':
      default:
        return totalOrders;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue & Orders'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDriverData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadDriverData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeHeader(),
                      const SizedBox(height: 24),
                      _buildRevenueOverview(),
                      const SizedBox(height: 24),
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),
                      _buildFilteredStats(),
                      const SizedBox(height: 24),
                      _buildOrdersList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.green[50],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      currentUser?.name ?? 'Driver',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Track your earnings and delivery performance',
            style: TextStyle(
              color: Colors.green[50],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenue Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildRevenueCard(
              'Today',
              todayRevenue,
              todayOrders,
              Icons.today,
              Colors.blue,
            ),
            _buildRevenueCard(
              'This Month',
              monthRevenue,
              monthOrders,
              Icons.calendar_month,
              Colors.orange,
            ),
            _buildRevenueCard(
              'This Year',
              yearRevenue,
              yearOrders,
              Icons.date_range,
              Colors.purple,
            ),
            _buildRevenueCard(
              'All Time',
              totalRevenue,
              totalOrders,
              Icons.all_inclusive,
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueCard(
    String title,
    double revenue,
    int orders,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RM ${revenue.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$orders orders',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Period',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPeriodChip('Today', 'today', Icons.today),
              const SizedBox(width: 8),
              _buildPeriodChip('This Month', 'month', Icons.calendar_month),
              const SizedBox(width: 8),
              _buildPeriodChip('This Year', 'year', Icons.date_range),
              const SizedBox(width: 8),
              _buildPeriodChip('All Time', 'all', Icons.all_inclusive),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value, IconData icon) {
    final isSelected = selectedPeriod == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          selectedPeriod = value;
        });
      },
      selectedColor: Colors.green[600],
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildFilteredStats() {
    final filteredRevenue = _getFilteredRevenue();
    final filteredOrders = _getFilteredOrderCount();
    final averagePerOrder = filteredOrders > 0 ? filteredRevenue / filteredOrders : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Period Revenue',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'RM ${filteredRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.blue[200],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '$filteredOrders',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.blue[200],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Avg/Order',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'RM ${averagePerOrder.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final filteredGroupOrders = _getFilteredGroupOrders();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed Group Orders (${filteredGroupOrders.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        if (filteredGroupOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed group orders found for this period',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed group orders will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredGroupOrders.length,
            itemBuilder: (context, index) {
              final groupOrder = filteredGroupOrders[index];
              return _buildGroupOrderCard(groupOrder);
            },
          ),
      ],
    );
  }

  Widget _buildGroupOrderCard(GroupOrder groupOrder) {
    final completionDate = groupOrder.completedAt?.toDate() ?? groupOrder.updatedAt.toDate();
    final statusColor = _getStatusColor(groupOrder.status);

    // Calculate total revenue for this group order
    double groupRevenue = 0.0;
    int orderCount = 0;
    final groupOrdersInList = allOrders.where((order) => order.groupId == groupOrder.id).toList();
    
    for (var order in groupOrdersInList) {
      groupRevenue += order.deliveryFeeAsDouble;
      orderCount++;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  groupOrder.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'RM ${groupRevenue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Group Order ID: ${groupOrder.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.delivery_dining, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$orderCount delivery orders',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          
          if (groupOrder.scheduledTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Scheduled: ${DateFormat('MMM dd, yyyy • hh:mm a').format(groupOrder.scheduledTime!.toDate())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Completed: ${DateFormat('MMM dd, yyyy • hh:mm a').format(completionDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'delivering':
        return Colors.blue;
      case 'picked_up':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
