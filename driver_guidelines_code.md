# Driver Module Guidelines & Code Documentation

## Overview
This document provides comprehensive guidelines and code explanations for the MealMommy driver module, covering all functionality including maps, routes, location tracking, order management, chat integration, and revenue calculations.

## Table of Contents
1. [State Variables & Initialization](#state-variables--initialization)
2. [Location Management](#location-management)
3. [Order Management System](#order-management-system)
4. [Route & Map Integration](#route--map-integration)
5. [Order Acceptance Process](#order-acceptance-process)
6. [Live Delivery Navigation](#live-delivery-navigation)
7. [Chat System Integration](#chat-system-integration)
8. [Revenue Calculations](#revenue-calculations)
9. [Function Connectivity Map](#function-connectivity-map)
10. [Implementation Examples](#implementation-examples)

---

## State Variables & Initialization

### Core State Variables
```dart
class _DriverHomeState extends State<DriverHome> with TickerProviderStateMixin {
  // User & Authentication
  AppUser? currentUser;                    // Current logged-in driver
  DeliveryPreferences? deliveryPreferences; // Driver's delivery settings
  
  // Order Management
  List<GroupOrder> groupOrders = [];       // All available orders
  List<GroupOrder> filteredGroupOrders = []; // Filtered display list
  List<Order> currentGroupDeliveries = []; // Current group delivery data
  
  // Location & Navigation
  LatLng? driverLocation;                  // Real-time driver position
  StreamSubscription<LatLng>? _locationSubscription; // Location updates
  late MapController _mapController;       // Map control for centering
  
  // Route Visualization
  List<LatLng> routePoints = [];          // Route polyline points
  List<LatLng> allDeliveryLocations = []; // All delivery markers
  LatLng? selectedOrderLocation;          // Selected order destination
  String? selectedOrderId;                // Currently selected order ID
  
  // UI State
  bool isLoading = false;                 // Loading indicator
  bool isOnline = false;                  // Driver availability status
  String selectedFilter = 'all';         // Order filter setting
  
  // Real-time Updates
  StreamSubscription<QuerySnapshot>? _ordersSubscription; // Firestore listener
}
```

### Initialization Flow
```dart
@override
void initState() {
  super.initState();
  // 1. Initialize UI components
  filteredGroupOrders = [];
  _mapController = MapController();
  _setupAnimations();
  
  // 2. Start initialization chain
  _initializeLocationAndUser();
}

// Initialization Chain: Location → User → Orders
Future<void> _initializeLocationAndUser() async {
  await _loadCurrentUser();      // Load user data first
  await _initializeLocationServices(); // Then location services
}
```

---

## Location Management

### Location Service Integration
```dart
Future<void> _initializeLocationServices() async {
  try {
    // 1. Request Location Permission
    final permissionResult = await LocationService.requestLocationPermission();
    
    if (permissionResult.granted) {
      // 2. Get Initial Location
      final initialLocation = await LocationService.getCurrentPosition();
      if (initialLocation != null) {
        setState(() {
          driverLocation = initialLocation;
        });
        // 3. Center Map on Initial Location
        _mapController.move(initialLocation, 13.0);
      }
      
      // 4. Start Continuous Location Tracking
      final trackingStarted = await LocationService.instance.startLocationTracking();
      if (trackingStarted) {
        _setupLocationStream();
      }
    } else {
      _showLocationPermissionDialog(permissionResult);
    }
  } catch (e) {
    _showLocationErrorDialog('Failed to initialize location: $e');
  }
}
```

### Real-time Location Updates
```dart
void _setupLocationStream() {
  _locationSubscription = LocationService.instance.locationStream.listen(
    (LatLng newLocation) {
      final oldLocation = driverLocation;
      setState(() {
        driverLocation = newLocation;
      });
      
      // Auto-center map on new location
      _mapController.move(newLocation, _mapController.camera.zoom);
      
      // Refresh orders if significant movement (100+ meters)
      if (oldLocation != null) {
        final distanceMoved = LocationService.getDistanceBetween(oldLocation, newLocation);
        if (distanceMoved > 100) {
          print('Significant location change, refreshing orders...');
          _loadGroupOrders();
        }
      } else {
        // First location - load orders
        _loadGroupOrders();
      }
    },
    onError: (error) => print('Location stream error: $error'),
  );
}
```

---

## Order Management System

### Order Loading Chain
```dart
Future<void> _loadGroupOrders() async {
  // Prerequisites Check
  if (currentUser == null || deliveryPreferences == null || driverLocation == null) {
    return;
  }
  
  setState(() { isLoading = true; });
  
  try {
    // 1. Fetch Orders from Service
    final orders = await getAllOrders();
    
    // 2. Update State
    setState(() {
      groupOrders = orders;
      isLoading = false;
    });
    
    // 3. Apply Current Filter
    _applyFilter();
  } catch (e) {
    setState(() { isLoading = false; });
    print('Error loading orders: $e');
  }
}
```

### Order Items Database Schema
```dart
// Order Items Collection Structure (exact schema):
{
  'meal_id': 'oncBK7euW3Guom4rD8Rt', // String - reference to meals collection
  'order_id': '2uJeI578559G9PkNHQFQ', // String - reference to orders collection  
  'quantity': 4, // Number - quantity of this meal
  'subtotal': 90, // Number - subtotal for this item (no decimals)
}

// Note: Order items fetching is handled in the live delivery page
```

### Order Filtering System
```dart
void _applyFilter() {
  List<GroupOrder> filtered = [];
  final DateTime now = DateTime.now();
  
  switch (selectedFilter) {
    case 'all':
      filtered = List.from(groupOrders);
      break;
    case 'my_orders':
      filtered = groupOrders.where((order) => 
        order.driverId == currentUser!.uid).toList();
      break;
    case 'available':
      filtered = groupOrders.where((order) => 
        order.driverId == null || order.driverId!.isEmpty).toList();
      break;
    case 'urgent':
      filtered = groupOrders.where((order) {
        if (order.scheduledTime == null) return false;
        final timeDiff = order.scheduledTime!.toDate().difference(now);
        return timeDiff.inHours <= 2; // Within 2 hours
      }).toList();
      break;
  }
  
  setState(() {
    filteredGroupOrders = filtered;
  });
}
```

### Order Sorting Logic
```dart
Future<List<GroupOrder>> getAllOrders() async {
  final ordersData = await OrderService.getAllOrders(
    currentUserId: currentUser?.uid,
    deliveryPreferences: deliveryPreferences,
    driverLocation: driverLocation!,
  );
  
  final orders = ordersData.map((data) => 
    GroupOrder.fromFirestore(data, data['id'] ?? '')).toList();
  
  // Smart Sorting Algorithm
  orders.sort((a, b) {
    final bool aIsMyOrder = a.driverId == currentUser?.uid;
    final bool bIsMyOrder = b.driverId == currentUser?.uid;
    
    // Priority 1: My orders first
    if (aIsMyOrder && !bIsMyOrder) return -1;
    if (!aIsMyOrder && bIsMyOrder) return 1;
    
    // Priority 2: Time-based sorting
    if (a.scheduledTime == null && b.scheduledTime == null) return 0;
    if (a.scheduledTime == null) return 1;
    if (b.scheduledTime == null) return -1;
    
    final DateTime aTime = a.scheduledTime!.toDate();
    final DateTime bTime = b.scheduledTime!.toDate();
    
    // For my orders: Most urgent first
    if (aIsMyOrder && bIsMyOrder) {
      final Duration aDiff = aTime.difference(DateTime.now()).abs();
      final Duration bDiff = bTime.difference(DateTime.now()).abs();
      return aDiff.compareTo(bDiff);
    }
    
    // For available orders: Earliest first
    return aTime.compareTo(bTime);
  });
  
  return orders;
}
```

---

## Route & Map Integration

### Route Generation Process
```dart
void onOrderTapped(GroupOrder order) async {
  // 1. Clear Previous Route
  if (selectedOrderId == order.id) {
    clearRoute();
    return;
  }
  
  // 2. Set Selection State
  setState(() {
    selectedOrderId = order.id;
  });
  
  try {
    // 3. Get Group Deliveries
    final List<Order> groupDeliveries = await getOrdersByGroupId(order.id);
    
    if (groupDeliveries.isNotEmpty) {
      // 4. Optimize Delivery Route
      final deliveriesData = groupDeliveries.map((order) => 
        order.toMap()..['id'] = order.id).toList();
      final optimizedWaypoints = await optimizeDeliveryRoute(deliveriesData);
      
      // 5. Set Map Markers
      setState(() {
        selectedOrderLocation = optimizedWaypoints.last;
        allDeliveryLocations = optimizedWaypoints.skip(1).toList();
        currentGroupDeliveries = groupDeliveries;
      });
      
      // 6. Generate Visual Route
      await getOptimizedGroupRoute(optimizedWaypoints);
      
      // 7. Animate UI
      _expansionController.forward();
    }
  } catch (e) {
    print('Error loading group deliveries: $e');
  }
}
```

### Route Visualization
```dart
List<Polyline> _createColoredRouteSegments() {
  if (routePoints.isEmpty || allDeliveryLocations.isEmpty) return [];
  
  final List<Color> segmentColors = [
    Colors.red, Colors.green, Colors.orange, Colors.purple,
    Colors.cyan, Colors.pink, Colors.amber, Colors.indigo,
  ];
  
  List<Polyline> polylines = [];
  int pointsPerSegment = (routePoints.length / (allDeliveryLocations.length + 1)).round();
  
  for (int i = 0; i < allDeliveryLocations.length; i++) {
    int startIndex = i * pointsPerSegment;
    int endIndex = math.min((i + 1) * pointsPerSegment + 1, routePoints.length);
    
    if (startIndex < routePoints.length && endIndex > startIndex) {
      polylines.add(Polyline(
        points: routePoints.sublist(startIndex, endIndex),
        strokeWidth: 4.0,
        color: segmentColors[i % segmentColors.length],
      ));
    }
  }
  
  return polylines;
}
```

### Map Marker System
```dart
MarkerLayer(
  markers: [
    // Driver Location Marker
    if (driverLocation != null)
      Marker(
        point: driverLocation!,
        child: const Icon(Icons.local_shipping, color: Colors.green, size: 40),
      ),
    
    // Delivery Location Markers with Color Coding
    ...allDeliveryLocations.asMap().entries.map((entry) {
      final int index = entry.key;
      final LatLng location = entry.value;
      final bool isVendor = index == 0 && allDeliveryLocations.length > 1;
      
      return Marker(
        point: location,
        child: Icon(
          isVendor ? Icons.store : Icons.location_on,
          color: isVendor ? Colors.blue : markerColors[index % markerColors.length],
          size: isVendor ? 40 : 35,
        ),
      );
    }).toList(),
  ],
)
```

---

## Order Acceptance Process

### Order Acceptance Validation
```dart
void onAcceptOrder(GroupOrder order) async {
  // 1. Online Status Check
  if (!isOnline) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must be ONLINE to accept orders'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // 2. User Authentication Check
  if (currentUser == null || order.id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error: Unable to accept order'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  try {
    // 3. Service Call
    final orderData = order.toMap()..['id'] = order.id;
    final success = await OrderService.acceptOrder(
      order: orderData,
      currentUserId: currentUser!.uid,
    );
    
    if (success) {
      // 4. Update Local State
      setState(() {
        final orderIndex = groupOrders.indexWhere((o) => o.id == order.id);
        if (orderIndex != -1) {
          groupOrders[orderIndex] = order.copyWith(
            assignedAt: Timestamp.now(),
          );
        }
      });
      
      // 5. Success Feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.id} accepted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // 6. Handle Conflicts
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order already accepted by another driver'),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadGroupOrders(); // Refresh data
    }
  } catch (e) {
    // 7. Error Handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error accepting order: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### Driver Status Management
```dart
void toggleOnlineStatus() {
  setState(() {
    isOnline = !isOnline;
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isOnline 
          ? 'You are now ONLINE and available for orders' 
          : 'You are now OFFLINE',
      ),
      backgroundColor: isOnline ? Colors.green : Colors.orange,
    ),
  );
}
```

---

## Live Delivery Navigation

### Navigation Preparation (Order Items Fetched in Live Delivery Page)
```dart
void _navigateToLiveDelivery(GroupOrder order) async {
  // 1. Location Validation
  if (driverLocation == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location not available. Please enable location permissions.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // 2. Time Validation (30-minute window)
  if (order.scheduledTime != null) {
    final now = DateTime.now();
    final scheduledTime = order.scheduledTime!.toDate();
    final timeDifference = scheduledTime.difference(now);
    
    if (timeDifference.inMinutes > 30) {
      final hoursUntil = timeDifference.inHours;
      final minutesUntil = timeDifference.inMinutes % 60;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot start delivery yet. Wait until 30 minutes before pickup.\n'
            'Time remaining: ${hoursUntil > 0 ? '${hoursUntil}h ' : ''}${minutesUntil}m',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
  }
  
  try {
    // 3. Data Preparation
    String groupId = order.id;
    final List<Order> groupDeliveries = await getOrdersByGroupId(groupId);
    final deliveriesData = groupDeliveries.map((order) => 
      order.toMap()..['id'] = order.id).toList();
    
    // 4. Route Optimization
    final optimizedWaypoints = await optimizeDeliveryRoute(deliveriesData);
    
    // 5. Vendor Information
    LatLng? vendorLocation;
    Map<String, dynamic>? vendorInfo;
    if (groupDeliveries.isNotEmpty && groupDeliveries[0].vendorId.isNotEmpty) {
      vendorLocation = await getVendorLocation(groupDeliveries[0].vendorId);
      vendorInfo = await DeliveryRouteService.getVendorInfo(groupDeliveries[0].vendorId);
    }
    
    // 6. Navigation (Order Items Will Be Fetched in Live Delivery Page)
    final result = await Navigator.pushNamed(
      context,
      '/driver/live-delivery',
      arguments: {
        'groupOrder': order.toMap()..['id'] = order.id,
        'deliveries': deliveriesData,
        'optimizedWaypoints': optimizedWaypoints,
        'vendorLocation': vendorLocation,
        'vendorInfo': vendorInfo,
        'currentUser': currentUser,
        'driverLocation': driverLocation!,
      },
    );
    
    // 7. Post-Navigation Refresh
    if (result != null || mounted) {
      await _loadGroupOrders();
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading delivery data: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### Order Items Fetching (Done in Live Delivery Page)
```dart
// In Live Delivery Page - fetch order items with exact schema:
Future<List<Map<String, dynamic>>> getOrderItemsForDelivery(String orderId) async {
  final orderItemsSnapshot = await FirebaseFirestore.instance
      .collection('order_items')
      .where('order_id', isEqualTo: orderId)
      .get();

  List<Map<String, dynamic>> items = [];
  
  for (var itemDoc in orderItemsSnapshot.docs) {
    final itemData = itemDoc.data();
    
    // Get meal details
    final mealDoc = await FirebaseFirestore.instance
        .collection('meals')
        .doc(itemData['meal_id'])
        .get();
    
    if (mealDoc.exists) {
      final mealData = mealDoc.data()!;
      items.add({
        'meal_id': itemData['meal_id'], // String
        'order_id': itemData['order_id'], // String
        'quantity': itemData['quantity'], // Number
        'subtotal': itemData['subtotal'], // Number
        'meal_name': mealData['name'],
        'meal_price': mealData['price'],
      });
    }
  }
  
  return items;
}
```

---

## Chat System Integration

### Chat Button & Unread Detection
```dart
Widget _buildChatButton() {
  if (currentUser == null) return SizedBox.shrink();

  return Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      color: Colors.green[600],
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: InkWell(
      onTap: () async { await _navigateToActiveDeliveryChat(); },
      child: Stack(
        children: [
          Center(child: Icon(Icons.chat_bubble, color: Colors.white, size: 24)),
          // Unread Messages Indicator
          StreamBuilder<bool>(
            stream: _getUnreadMessagesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return Positioned(
                  right: 10, top: 10,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    ),
  );
}
```

### Chat Navigation Logic
```dart
Future<void> _navigateToActiveDeliveryChat() async {
  if (currentUser == null) return;
  
  try {
    // 1. Get Active Chat Rooms
    final chatRooms = await ChatService.getUserChatRooms(currentUser!.uid);
    
    if (chatRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active chat rooms found')),
      );
      return;
    }

    if (chatRooms.length == 1) {
      // 2. Direct Navigation (Single Chat)
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ChatPage(
          chatRoomId: chatRooms.first['id'],
          currentUserId: currentUser!.uid,
        ),
      ));
    } else {
      // 3. Chat Room Selection (Multiple Chats)
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ChatRoomListPage(
          currentUserId: currentUser!.uid,
          chatRooms: chatRooms,
        ),
      ));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to open chat'), backgroundColor: Colors.red),
    );
  }
}
```

### Unread Messages Stream
```dart
Stream<bool> _getUnreadMessagesStream() {
  if (currentUser == null) return Stream.value(false);
  return ChatService.hasUnreadMessages(currentUser!.uid).asStream();
}
```

---

## Revenue Calculations

### Distance Calculation
```dart
double _calculateTotalDistance() {
  if (allDeliveryLocations.isEmpty || driverLocation == null) return 0.0;
  
  double totalDistance = 0.0;
  List<LatLng> allPoints = [driverLocation!, ...allDeliveryLocations];
  
  // Calculate distance between consecutive route points
  for (int i = 0; i < allPoints.length - 1; i++) {
    totalDistance += calculateDistance(allPoints[i], allPoints[i + 1]);
  }
  
  return totalDistance;
}

double calculateDistance(LatLng point1, LatLng point2) {
  return RouteService.calculateDistance(point1, point2);
}
```

### Delivery Fee Calculation
```dart
double _calculateTotalDeliveryFee() {
  if (currentGroupDeliveries.isEmpty) return 0.0;
  
  double totalFee = 0.0;
  for (var delivery in currentGroupDeliveries) {
    totalFee += delivery.deliveryFeeAsDouble;
  }
  
  return totalFee;
}
```

### Revenue Display Example
```dart
// In UI builder method
if (currentGroupDeliveries.isNotEmpty) {
  final totalDistance = _calculateTotalDistance();
  final totalFee = _calculateTotalDeliveryFee();
  
  return Container(
    child: Column(
      children: [
        Text('Total Distance: ${totalDistance.toStringAsFixed(1)} km'),
        Text('Total Delivery Fee: RM ${totalFee.toStringAsFixed(2)}'),
        Text('Estimated Earnings: RM ${(totalFee * 0.8).toStringAsFixed(2)}'),
      ],
    ),
  );
}
```

---

## Function Connectivity Map

### Complete System Flow
```
App Startup → initState()
    ↓
_initializeLocationAndUser()
    ↓
_loadCurrentUser() → AuthService.getCurrentUserData()
    ↓
_loadDeliveryPreferences() → FirebaseFirestore.delivery_preferences
    ↓
_initializeLocationServices() → LocationService.requestLocationPermission()
    ↓
LocationService.getCurrentPosition() → driverLocation
    ↓
_mapController.move() → Center map on driver
    ↓
LocationService.startLocationTracking() → Continuous GPS updates
    ↓
locationStream.listen() → Real-time location updates
    ↓
_loadGroupOrders() → Load available orders
    ↓
OrderService.getAllOrders() → Fetch from Firestore
    ↓
_applyFilter() → Filter orders by criteria
    ↓
setState() → Update UI with filtered orders

Order Selection → onOrderTapped()
    ↓
getOrdersByGroupId() → Get related deliveries
    ↓
getGroupOrderItemsWithMealDetails() → Get order items with meal names
    ↓
optimizeDeliveryRoute() → Calculate optimal route
    ↓
getOptimizedGroupRoute() → Generate visual route
    ↓
setState() → Update map with route & markers
    ↓
Show pickup summary with total items

Order Acceptance → onAcceptOrder()
    ↓
Check isOnline status
    ↓
OrderService.acceptOrder() → Update Firestore
    ↓
setState() → Update local order state
    ↓
_loadGroupOrders() → Refresh order list

Live Delivery → _navigateToLiveDelivery()
    ↓
Validate timing (30-minute window)
    ↓
getOrdersByGroupId() → Get delivery orders
    ↓
getGroupOrderItemsWithMealDetails() → Get pickup items with meal details
    ↓
Prepare delivery data (routes, vendor info, order items)
    ↓
Navigator.pushNamed('/driver/live-delivery') → Navigate to delivery page
    ↓
Return → _loadGroupOrders() → Refresh orders

Order Items Flow → getOrderItemsWithMealDetails()
    ↓
FirebaseFirestore.order_items.where('order_id') → Get order items
    ↓
FirebaseFirestore.meals.doc(meal_id) → Get meal details
    ↓
Combine item data with meal name and price
    ↓
Return structured order items list

Chat System → _buildChatButton()
    ↓
StreamBuilder<bool> → Monitor unread messages
    ↓
_navigateToActiveDeliveryChat() → Open chat interface
    ↓
ChatService.getUserChatRooms() → Get active chats
    ↓
Navigate to ChatPage or ChatRoomListPage

Real-time Updates → _setupRealTimeListener()
    ↓
FirebaseFirestore.grouporders.snapshots() → Listen to order changes
    ↓
FirebaseFirestore.orders.snapshots() → Listen to delivery status
    ↓
_loadGroupOrders() → Auto-refresh on changes
```

### Service Dependencies
```
LocationService:
├── requestLocationPermission()
├── getCurrentPosition()
├── startLocationTracking()
├── locationStream
├── getDistanceBetween()
└── openLocationSettings()

OrderService:
├── getAllOrders()
├── getOrdersByGroupId()
├── acceptOrder()
└── updateOrderStatus()

RouteService:
├── getRoute()
├── getMultiPointRoute()
├── calculateDistance()
└── optimizeRoute()

DeliveryRouteService:
├── optimizeDeliveryRoute()
├── getVendorLocation()
└── getVendorInfo()

ChatService:
├── getUserChatRooms()
├── hasUnreadMessages()
└── createChatRoom()

AuthService:
├── getCurrentUserData()
├── currentUser
└── signOut()
```

---

## Implementation Examples

### Test Order Generation with Order Items
```dart
Future<void> _generateTestOrders() async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();
    
    // 1. Generate Test Meals
    final testMeals = [
      {
        'id': 'meal_nasi_lemak',
        'name': 'Nasi Lemak Special',
        'price': 15.00,
        'vendor_id': 'test_vendor_1',
      },
      {
        'id': 'meal_char_kuey_teow',
        'name': 'Char Kuey Teow',
        'price': 12.50,
        'vendor_id': 'test_vendor_1',
      },
      // ... more meals
    ];

    // Add meals to batch
    for (var meal in testMeals) {
      final mealRef = FirebaseFirestore.instance.collection('meals').doc(meal['id'] as String);
      batch.set(mealRef, meal);
    }
    
    // 2. Generate Group Order
    final groupOrderRef = FirebaseFirestore.instance.collection('grouporders').doc();
    final groupOrderData = {
      'driver_id': '', // Available for pickup
      'status': 'pending',
      'vendor_id': 'test_vendor_1',
      // ... other fields
    };
    batch.set(groupOrderRef, groupOrderData);

    // 3. Generate Individual Orders with Items
    final testOrders = [
      {
        'customer_name': 'John Doe',
        'total_amount': 60.00,
        'group_id': groupOrderRef.id,
        // ... other order fields
      },
      // ... more orders
    ];

    // 4. Generate Order Items
    final orderItemsData = [
      // John Doe's order items
      [
        {
          'meal_id': 'meal_nasi_lemak',
          'quantity': 4,
          'subtotal': 60.00,
        },
      ],
      // Jane Smith's order items  
      [
        {
          'meal_id': 'meal_char_kuey_teow',
          'quantity': 3,
          'subtotal': 37.50,
        },
      ],
      // ... more order items
    ];

    // 5. Add Orders and Items to Batch
    for (int i = 0; i < testOrders.length; i++) {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      batch.set(orderRef, testOrders[i]);
      
      // Add order items for this order
      for (var itemData in orderItemsData[i]) {
        final orderItemRef = FirebaseFirestore.instance.collection('order_items').doc();
        final orderItemWithOrderId = {
          ...itemData,
          'order_id': orderRef.id,
          'created_at': Timestamp.fromDate(now),
        };
        batch.set(orderItemRef, orderItemWithOrderId);
      }
    }

    // 6. Commit All Changes
    await batch.commit();
  } catch (e) {
    print('Error generating test orders: $e');
  }
}
```

### Adding New Filter Type
```dart
// 1. Add to filter dropdown
DropdownMenuItem(
  value: 'high_value',
  child: Text('High Value Orders'),
),

// 2. Add case to _applyFilter()
case 'high_value':
  filtered = groupOrders.where((order) {
    final totalValue = _calculateOrderValue(order);
    return totalValue > 50.0; // Orders over RM 50
  }).toList();
  break;

// 3. Implement calculation method
double _calculateOrderValue(GroupOrder order) {
  // Calculate based on order content
  return order.items.fold(0.0, (sum, item) => sum + item.price);
}
```

### Adding Custom Route Marker
```dart
// In MarkerLayer markers list
Marker(
  point: customLocation,
  child: Container(
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.local_gas_station, color: Colors.blue, size: 30),
        Positioned(
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('GAS', style: TextStyle(fontSize: 8)),
          ),
        ),
      ],
    ),
  ),
),
```

### Custom Real-time Listener
```dart
void _setupCustomListener() {
  FirebaseFirestore.instance
      .collection('driver_status')
      .doc(currentUser!.uid)
      .snapshots()
      .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          setState(() {
            isOnline = data?['is_online'] ?? false;
          });
        }
      });
}
```

---

## Troubleshooting Guide

### Common Issues & Solutions

1. **Location Not Updating**
   - Check LocationService.requestLocationPermission()
   - Verify _locationSubscription is not null
   - Ensure startLocationTracking() returns true

2. **Orders Not Loading**
   - Verify currentUser != null
   - Check deliveryPreferences != null
   - Ensure driverLocation != null
   - Check Firestore connection

3. **Route Not Displaying**
   - Verify routePoints.isNotEmpty
   - Check RouteService.getRoute() success
   - Ensure OSRM servers are accessible

4. **Map Not Centering**
   - Check _mapController initialization
   - Verify driverLocation is valid
   - Ensure _mapController.move() is called

5. **Chat Not Working**
   - Verify currentUser authentication
   - Check ChatService.getUserChatRooms()
   - Ensure chat permissions are set

---

## Best Practices

1. **Always check prerequisites before operations**
2. **Use try-catch blocks for all async operations**
3. **Provide user feedback for all actions**
4. **Cancel subscriptions in dispose()**
5. **Validate data before state updates**
6. **Use meaningful variable names**
7. **Keep functions focused and single-purpose**
8. **Handle edge cases (null values, empty lists)**
9. **Implement proper error handling**
10. **Test with real location data**

---

This documentation provides complete coverage of the driver module functionality, including all connectivity patterns, implementation details, and best practices for maintenance and extension.
