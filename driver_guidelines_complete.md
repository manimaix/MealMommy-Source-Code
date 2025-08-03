# MealMommy Driver Module - Complete Code Guidelines

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Data Models](#data-models)
4. [Core Services](#core-services)
5. [Driver Home Implementation](#driver-home-implementation)
6. [Live Delivery System](#live-delivery-system)
7. [Location Services](#location-services)
8. [Chat Integration](#chat-integration)
9. [Database Schema](#database-schema)
10. [State Management](#state-management)
11. [Error Handling](#error-handling)
12. [Testing & Debugging](#testing--debugging)
13. [Performance Optimization](#performance-optimization)
14. [Security Considerations](#security-considerations)

---

## Architecture Overview

The MealMommy driver module follows a modular Flutter architecture with clear separation of concerns:

### Core Components
- **Driver Home**: Main dashboard and test data generation
- **Live Delivery**: Real-time delivery tracking and management
- **Route Service**: Optimized route planning and navigation
- **Location Service**: GPS tracking and permission management
- **Chat Service**: Communication system (text-only)
- **Order Management**: Order lifecycle and status updates

### Design Patterns
- **StatefulWidget** pattern for reactive UI
- **Service Layer** for business logic separation
- **Repository Pattern** for data access
- **Observer Pattern** for real-time updates
- **State Management** through setState and StreamBuilder

---

## File Structure

```
lib/
├── driver/
│   ├── driver_home.dart           # Main driver dashboard
│   └── live_delivery_page.dart    # Live delivery tracking
├── services/
│   ├── route_service.dart         # Route optimization
│   ├── location_service.dart      # GPS and permissions
│   └── chat_service.dart          # Communication system
├── models/
│   ├── order_model.dart           # Order data structure
│   ├── group_order_model.dart     # Group order data
│   ├── app_user_model.dart        # User information
│   ├── chat_message_model.dart    # Chat messages
│   └── chat_room_model.dart       # Chat rooms
└── widgets/
    └── global_app_bar.dart        # Shared UI components
```

---

## Data Models

### Order Model
```dart
class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String vendorId;
  final String groupId;
  final String status;
  final double deliveryFee;
  final Timestamp? createdAt;
  final Timestamp? pickupTime;
  final Timestamp? deliveryTime;
  final Timestamp? updatedAt;

  // Key Methods
  double get deliveryFeeAsDouble => deliveryFee;
  
  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      customerId: data['customer_id'] ?? '',
      customerName: data['customer_name'] ?? '',
      customerPhone: data['customer_phone'] ?? '',
      deliveryAddress: data['delivery_address'] ?? '',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      vendorId: data['vendor_id'] ?? '',
      groupId: data['group_id'] ?? '',
      status: data['status'] ?? 'pending',
      deliveryFee: (data['delivery_fee'] ?? 0).toDouble(),
      createdAt: data['created_at'],
      pickupTime: data['pickup_time'],
      deliveryTime: data['delivery_time'],
      updatedAt: data['updated_at'],
    );
  }
}
```

### Group Order Model
```dart
class GroupOrder {
  final String id;
  final String vendorId;
  final String driverId;
  final String status;
  final int? currentDeliveryIndex;
  final int? currentNavigationStep;
  final Timestamp? createdAt;
  final Timestamp? completedAt;
  final Timestamp? updatedAt;

  factory GroupOrder.fromFirestore(Map<String, dynamic> data, String id) {
    return GroupOrder(
      id: id,
      vendorId: data['vendor_id'] ?? '',
      driverId: data['driver_id'] ?? '',
      status: data['status'] ?? 'pending',
      currentDeliveryIndex: data['current_delivery_index'],
      currentNavigationStep: data['current_navigation_step'],
      createdAt: data['created_at'],
      completedAt: data['completed_at'],
      updatedAt: data['updated_at'],
    );
  }
}
```

### Chat Message Model (Text-Only)
```dart
class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String? text;
  final String type; // 'text' or 'system'
  final Timestamp sentAt;

  bool get isSystemMessage => senderId == 'system';
  bool get isTextMessage => type == 'text';

  factory ChatMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown User',
      text: data['text'],
      type: data['type'] ?? 'text',
      sentAt: data['sentAt'] ?? Timestamp.now(),
    );
  }
}
```

---

## Core Services

### Route Service Implementation
```dart
class RouteService {
  static const List<String> _osrmServers = [
    'https://router.project-osrm.org',
    'https://routing.openstreetmap.de',
    'https://osrm.map.bf-ds.de',
  ];

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Optimize delivery route using nearest neighbor algorithm
  static List<LatLng> optimizeRoute(LatLng start, List<LatLng> destinations) {
    List<LatLng> optimized = [start];
    List<LatLng> remaining = List.from(destinations);
    
    LatLng current = start;
    
    while (remaining.isNotEmpty) {
      double minDistance = double.infinity;
      int nearestIndex = 0;
      
      for (int i = 0; i < remaining.length; i++) {
        double distance = calculateDistance(current, remaining[i]);
        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }
      
      current = remaining[nearestIndex];
      optimized.add(current);
      remaining.removeAt(nearestIndex);
    }
    
    return optimized;
  }

  // Get route from OSRM servers with fallback
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    for (String server in _osrmServers) {
      try {
        String coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
        final String url = '$server/route/v1/driving/$coordinates?overview=full&geometries=geojson';

        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'MealMommy/1.0 (Flutter App)'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
            return coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
          }
        }
      } catch (e) {
        print('Failed to get route from $server: $e');
        continue;
      }
    }
    
    // Fallback: Direct route
    return _createDirectRoute(start, end);
  }

  static List<LatLng> _createDirectRoute(LatLng start, LatLng end) {
    List<LatLng> route = [start];
    const int points = 10;
    
    for (int i = 1; i <= points; i++) {
      double progress = i / points;
      double lat = start.latitude + (end.latitude - start.latitude) * progress;
      double lng = start.longitude + (end.longitude - start.longitude) * progress;
      route.add(LatLng(lat, lng));
    }
    
    return route;
  }
}
```

### Location Service Implementation
```dart
class LocationService {
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  static Future<LatLng?> getCurrentLocation() async {
    try {
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  static Stream<LatLng> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}
```

### Chat Service (Text-Only Implementation)
```dart
class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create order chat room
  static Future<String?> createOrderChatRoom({
    required String groupOrderId,
    required String driverId,
    required String vendorId,
    List<String> customerIds = const [],
  }) async {
    try {
      List<String> participants = [driverId, vendorId, ...customerIds];
      participants = participants.where((id) => id.isNotEmpty).toSet().toList();

      final chatRoomData = {
        'group_id': groupOrderId,
        'participants': participants,
        'driver_id': driverId,
        'vendor_id': vendorId,
        'customer_ids': customerIds,
        'created_at': Timestamp.now(),
        'last_message': 'Chat room created',
        'last_message_time': Timestamp.now(),
        'is_active': true,
      };

      final docRef = await _firestore.collection('chatroom').add(chatRoomData);
      
      // Send welcome system message
      await _sendSystemMessage(docRef.id, 'Welcome to the order chat room! 🚚');
      
      return docRef.id;
    } catch (e) {
      print('Error creating chat room: $e');
      return null;
    }
  }

  // Send system message
  static Future<void> _sendSystemMessage(String chatRoomId, String message) async {
    try {
      await _firestore.collection('chatmessages').add({
        'chatRoomId': chatRoomId,
        'senderId': 'system',
        'senderName': 'System',
        'text': message,
        'type': 'system',
        'sentAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  // Get user chat rooms
  static Future<List<Map<String, dynamic>>> getUserChatRooms(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatroom')
          .where('participants', arrayContains: userId)
          .where('is_active', isEqualTo: true)
          .orderBy('last_message_time', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting user chat rooms: $e');
      return [];
    }
  }

  // Check for unread messages
  static Future<bool> hasUnreadMessages(String userId) async {
    try {
      final chatRooms = await getUserChatRooms(userId);
      
      for (var room in chatRooms) {
        final unreadSnapshot = await _firestore
            .collection('chatmessages')
            .where('chatRoomId', isEqualTo: room['id'])
            .where('senderId', isNotEqualTo: userId)
            .where('sentAt', isGreaterThan: room['last_read_time'] ?? Timestamp.fromDate(DateTime(2020)))
            .limit(1)
            .get();
            
        if (unreadSnapshot.docs.isNotEmpty) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking unread messages: $e');
      return false;
    }
  }

  // Complete order chat room
  static Future<void> completeOrderChatRoom(String groupOrderId) async {
    try {
      final snapshot = await _firestore
          .collection('chatroom')
          .where('group_id', isEqualTo: groupOrderId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'is_active': false,
          'completed_at': Timestamp.now(),
        });
        
        await _sendSystemMessage(doc.id, 'Order completed! Chat room is now archived. 📦✅');
      }
    } catch (e) {
      print('Error completing chat room: $e');
    }
  }
}
```

---

## Driver Home Implementation

### Core Features
- Location permission management
- Test data generation
- Group order fetching
- Navigation to live delivery

### Implementation Details
```dart
class DriverHomePage extends StatefulWidget {
  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  AppUser? currentUser;
  List<GroupOrder> availableOrders = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAvailableOrders();
  }

  // Generate test data with proper schema
  Future<void> _generateTestOrders() async {
    setState(() { isLoading = true; });
    
    try {
      const String testMealId = 'oncBK7euW3Guom4rD8Rt'; // Existing meal ID
      
      // Create group order
      final groupOrderRef = await FirebaseFirestore.instance
          .collection('grouporders')
          .add({
        'vendor_id': 'test_vendor_001',
        'driver_id': currentUser?.uid ?? '',
        'status': 'assigned',
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });

      // Create individual orders
      final List<String> orderIds = [];
      final testCustomers = [
        {
          'name': 'Alice Wong',
          'phone': '+60123456789',
          'address': 'Block A, Taman Melawati, Kuala Lumpur',
          'lat': 3.2050,
          'lng': 101.7390,
        },
        {
          'name': 'Bob Lim',
          'phone': '+60198765432',
          'address': 'Jalan Ampang, KLCC, Kuala Lumpur',
          'lat': 3.1478,
          'lng': 101.7090,
        },
        {
          'name': 'Carol Tan',
          'phone': '+60187654321',
          'address': 'Bangsar South, Kuala Lumpur',
          'lat': 3.1167,
          'lng': 101.6667,
        },
      ];

      final batch = FirebaseFirestore.instance.batch();
      
      for (int i = 0; i < testCustomers.length; i++) {
        final customer = testCustomers[i];
        
        // Create order
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        batch.set(orderRef, {
          'customer_id': 'test_customer_${i + 1}',
          'customer_name': customer['name'],
          'customer_phone': customer['phone'],
          'delivery_address': customer['address'],
          'latitude': customer['lat'],
          'longitude': customer['lng'],
          'vendor_id': 'test_vendor_001',
          'group_id': groupOrderRef.id,
          'status': 'pending',
          'delivery_fee': 5.0 + (i * 2.0),
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });
        
        orderIds.add(orderRef.id);
        
        // Create order items with exact schema
        final orderItemRef = FirebaseFirestore.instance.collection('order_items').doc();
        batch.set(orderItemRef, {
          'meal_id': testMealId,
          'order_id': orderRef.id,
          'quantity': (i + 1) * 2, // 2, 4, 6 items
          'subtotal': (15.0 + (i * 5.0)) * (i + 1) * 2, // Price * quantity
        });
      }
      
      await batch.commit();
      
      print('✅ Test data generated successfully');
      print('📦 Group Order ID: ${groupOrderRef.id}');
      print('📋 Individual Orders: ${orderIds.length}');
      
      await _loadAvailableOrders();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test orders created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error generating test data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating test orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() { isLoading = false; });
  }

  // Start delivery process
  Future<void> _startDelivery(GroupOrder groupOrder) async {
    // Get driver location
    final driverLocation = await LocationService.getCurrentLocation();
    if (driverLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get your location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fetch orders and vendor info
    final deliveries = await _fetchGroupOrderDeliveries(groupOrder.id);
    final vendorInfo = await _fetchVendorInfo(groupOrder.vendorId);
    
    if (deliveries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No deliveries found for this order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Optimize route
    final vendorLocation = LatLng(
      vendorInfo?['latitude']?.toDouble() ?? 3.139,
      vendorInfo?['longitude']?.toDouble() ?? 101.6869,
    );
    
    final customerLocations = deliveries
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) => LatLng(d.latitude!, d.longitude!))
        .toList();
    
    final optimizedWaypoints = RouteService.optimizeRoute(
      vendorLocation,
      customerLocations,
    );

    // Navigate to live delivery
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveDeliveryPage(),
        settings: RouteSettings(
          arguments: {
            'groupOrder': groupOrder.toMap(),
            'deliveries': deliveries.map((d) => d.toMap()).toList(),
            'optimizedWaypoints': optimizedWaypoints,
            'vendorLocation': vendorLocation,
            'vendorInfo': vendorInfo,
            'currentUser': currentUser,
            'driverLocation': driverLocation,
          },
        ),
      ),
    );
  }
}
```

---

## Live Delivery System

### Core Features
- Real-time driver location updates
- Step-by-step navigation
- Order status management
- Retry mechanism for data loading
- Chat integration
- Vendor pickup summary

### Key Implementation Details

#### Driver Location Management
```dart
void _updateDriverLocationBasedOnStatus() {
  if (groupOrder == null) return;
  
  setState(() {
    if (currentStatus == 'Heading to Vendor') {
      // Keep original driver location
    } else if (currentStatus == 'At Vendor - Picking Up' || 
               currentStatus.startsWith('Heading to Customer')) {
      // Move to vendor location
      if (vendorLocation != null) {
        driverLocation = vendorLocation;
      }
    } else if (currentStatus.startsWith('At Customer') && currentStatus.contains('Delivering')) {
      // Move to current customer location
      if (currentDeliveryIndex < deliveries.length) {
        final currentDelivery = deliveries[currentDeliveryIndex];
        if (currentDelivery.latitude != null && currentDelivery.longitude != null) {
          driverLocation = LatLng(currentDelivery.latitude!, currentDelivery.longitude!);
        }
      }
    } else if (currentStatus == 'All Deliveries Complete') {
      // Stay at final delivery location
      if (deliveries.isNotEmpty) {
        final lastDelivery = deliveries.last;
        if (lastDelivery.latitude != null && lastDelivery.longitude != null) {
          driverLocation = LatLng(lastDelivery.latitude!, lastDelivery.longitude!);
        }
      }
    }
  });
}
```

#### Order Items Loading with Retry Logic
```dart
Future<void> _fetchOrderItemsWithRetry() async {
  try {
    final Map<String, List<Map<String, dynamic>>> fetchedOrderItems = {};
    
    for (final order in deliveries) {
      // Fetch order items
      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('order_items')
          .where('order_id', isEqualTo: order.id)
          .get();
      
      List<Map<String, dynamic>> itemsWithMealDetails = [];
      
      for (final itemDoc in orderItemsSnapshot.docs) {
        final itemData = itemDoc.data();
        final mealId = itemData['meal_id'] as String;
        
        // Fetch meal details
        final mealDoc = await FirebaseFirestore.instance
            .collection('meals')
            .doc(mealId)
            .get();
        
        if (mealDoc.exists) {
          final mealData = mealDoc.data()!;
          itemsWithMealDetails.add({
            'meal_id': mealId,
            'order_id': itemData['order_id'],
            'quantity': itemData['quantity'],
            'subtotal': itemData['subtotal'],
            'meal_name': mealData['name'] ?? 'Unknown Meal',
            'meal_price': mealData['price'] ?? 0,
            'meal_description': mealData['description'] ?? '',
          });
        }
      }
      
      fetchedOrderItems[order.id] = itemsWithMealDetails;
    }
    
    setState(() {
      orderItems = fetchedOrderItems;
      isLoadingOrderItems = false;
    });
    
    // Show success message if retries occurred
    if (orderItemsRetryCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order items loaded successfully after ${orderItemsRetryCount + 1} attempts'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print('Error fetching order items (attempt ${orderItemsRetryCount + 1}): $e');
    
    if (orderItemsRetryCount < maxRetryAttempts - 1) {
      setState(() {
        orderItemsRetryCount++;
      });
      
      // Show retry message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loading order items failed, retrying... (${orderItemsRetryCount + 1}/$maxRetryAttempts)'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Wait and retry
      await Future.delayed(Duration(seconds: 2));
      await _fetchOrderItemsWithRetry();
    } else {
      // Max retries reached
      setState(() {
        isLoadingOrderItems = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load order items after $maxRetryAttempts attempts'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _fetchOrderItems(),
          ),
        ),
      );
    }
  }
}
```

#### Status Update System
```dart
void _updateDeliveryStatus() async {
  if (groupOrder == null) return;
  
  try {
    String newStatus = currentStatus;
    
    if (currentStatus == 'Heading to Vendor') {
      newStatus = 'At Vendor - Picking Up';
      // Update driver location to vendor
      if (vendorLocation != null) {
        setState(() {
          driverLocation = vendorLocation;
        });
      }
    } else if (currentStatus == 'At Vendor - Picking Up') {
      newStatus = 'Heading to Customer ${currentDeliveryIndex + 1}';
      await _updateAllOrdersToDelivering();
      setState(() {
        currentNavigationStep = 1;
      });
      await _generateCurrentStepRoute();
    } else if (currentStatus.startsWith('Heading to Customer')) {
      newStatus = 'At Customer ${currentDeliveryIndex + 1} - Delivering';
      // Update driver location to customer
      if (currentDeliveryIndex < deliveries.length) {
        final currentDelivery = deliveries[currentDeliveryIndex];
        if (currentDelivery.latitude != null && currentDelivery.longitude != null) {
          setState(() {
            driverLocation = LatLng(currentDelivery.latitude!, currentDelivery.longitude!);
          });
        }
      }
    } else if (currentStatus.startsWith('At Customer') && currentStatus.contains('Delivering')) {
      await _markCurrentOrderAsDelivered();
      
      if (currentDeliveryIndex + 1 < deliveries.length) {
        setState(() {
          currentDeliveryIndex++;
          currentNavigationStep++;
        });
        newStatus = 'Heading to Customer ${currentDeliveryIndex + 1}';
        await _generateCurrentStepRoute();
      } else {
        newStatus = 'All Deliveries Complete';
        setState(() {
          currentRoutePoints = [];
          // Update to final delivery location
          if (deliveries.isNotEmpty) {
            final lastDelivery = deliveries.last;
            if (lastDelivery.latitude != null && lastDelivery.longitude != null) {
              driverLocation = LatLng(lastDelivery.latitude!, lastDelivery.longitude!);
            }
          }
        });
        await _completeAllDeliveries();
        return;
      }
    }
    
    setState(() {
      currentStatus = newStatus;
    });
    
    // Update Firebase
    await FirebaseFirestore.instance
        .collection('grouporders')
        .doc(groupOrder!.id)
        .update({
      'status': newStatus,
      'current_delivery_index': currentDeliveryIndex,
      'current_navigation_step': currentNavigationStep,
      'updated_at': Timestamp.now(),
    });
  } catch (e) {
    print('Error updating delivery status: $e');
  }
}
```

---

## Database Schema

### Collections Structure

#### GroupOrders Collection
```json
{
  "id": "auto_generated",
  "vendor_id": "string",
  "driver_id": "string", 
  "status": "pending|assigned|delivering|completed",
  "current_delivery_index": "number",
  "current_navigation_step": "number",
  "created_at": "timestamp",
  "completed_at": "timestamp",
  "updated_at": "timestamp"
}
```

#### Orders Collection
```json
{
  "id": "auto_generated",
  "customer_id": "string",
  "customer_name": "string",
  "customer_phone": "string",
  "delivery_address": "string",
  "latitude": "number",
  "longitude": "number",
  "vendor_id": "string",
  "group_id": "string",
  "status": "pending|delivering|delivered",
  "delivery_fee": "number",
  "created_at": "timestamp",
  "pickup_time": "timestamp",
  "delivery_time": "timestamp",
  "updated_at": "timestamp"
}
```

#### Order Items Collection
```json
{
  "meal_id": "string",
  "order_id": "string", 
  "quantity": "number",
  "subtotal": "number"
}
```

#### Chat Rooms Collection
```json
{
  "group_id": "string",
  "participants": ["string"],
  "driver_id": "string",
  "vendor_id": "string", 
  "customer_ids": ["string"],
  "created_at": "timestamp",
  "last_message": "string",
  "last_message_time": "timestamp",
  "is_active": "boolean"
}
```

#### Chat Messages Collection
```json
{
  "chatRoomId": "string",
  "senderId": "string",
  "senderName": "string",
  "text": "string",
  "type": "text|system",
  "sentAt": "timestamp"
}
```

---

## State Management

### StatefulWidget Pattern
```dart
class _LiveDeliveryPageState extends State<LiveDeliveryPage> {
  // Core state variables
  GroupOrder? groupOrder;
  List<Order> deliveries = [];
  LatLng? driverLocation;
  String currentStatus = 'Heading to Vendor';
  int currentDeliveryIndex = 0;
  int currentNavigationStep = 0;
  
  // UI state
  bool isLoading = false;
  bool isLoadingOrderItems = false;
  
  // Order items with retry logic
  Map<String, List<Map<String, dynamic>>> orderItems = {};
  int orderItemsRetryCount = 0;
  static const int maxRetryAttempts = 5;
  
  // Route management
  List<LatLng> optimizedWaypoints = [];
  List<LatLng> currentRoutePoints = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliveryData();
    });
  }
  
  // State restoration from Firebase
  void _restoreCurrentStatus() {
    // Restore state based on Firebase data
    // Update driver location accordingly
    _updateDriverLocationBasedOnStatus();
  }
}
```

### Real-time Updates with StreamBuilder
```dart
StreamBuilder<bool>(
  stream: _hasUnreadMessagesStream(),
  builder: (context, snapshot) {
    final hasUnread = snapshot.data ?? false;
    return Stack(
      children: [
        FloatingActionButton(
          onPressed: _openChatRoom,
          child: const Icon(Icons.chat),
        ),
        if (hasUnread)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('!', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  },
)
```

---

## Error Handling

### Network Error Recovery
```dart
Future<List<LatLng>> _getCurrentStepRoute(LatLng start, LatLng end) async {
  final List<String> osrmServers = [
    'https://router.project-osrm.org',
    'https://routing.openstreetmap.de', 
    'https://osrm.map.bf-ds.de',
  ];

  for (String server in osrmServers) {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'MealMommy/1.0 (Flutter App)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Process successful response
        return routePoints;
      }
    } catch (e) {
      print('Failed to get route from $server: $e');
      continue; // Try next server
    }
  }
  
  // Fallback: Create direct route
  return _createDirectRoute(start, end);
}
```

### Database Error Handling
```dart
Future<void> _updateDeliveryStatus() async {
  try {
    // Perform database operations
    await FirebaseFirestore.instance
        .collection('grouporders')
        .doc(groupOrder!.id)
        .update(updateData);
        
  } catch (e) {
    print('Error updating delivery status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating status: $e'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'RETRY',
          onPressed: () => _updateDeliveryStatus(),
        ),
      ),
    );
  }
}
```

### Location Service Error Handling
```dart
static Future<LatLng?> getCurrentLocation() async {
  try {
    bool hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return null;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 10));
    
    return LatLng(position.latitude, position.longitude);
  } on TimeoutException {
    print('Location request timed out');
    return null;
  } catch (e) {
    print('Error getting current location: $e');
    return null;
  }
}
```

---

## Testing & Debugging

### Debug Logging
```dart
// Order items debug information
print('=== DEBUG: Order Items Fetched ===');
print('Total orders with items: ${orderItems.length}');
orderItems.forEach((orderId, items) {
  print('Order $orderId: ${items.length} items');
  for (var item in items) {
    print('  - ${item['meal_name']} x${item['quantity']} (RM${item['subtotal']})');
  }
});
print('================================');

// Driver location updates
print('🚗 Driver location updated to customer ${currentDeliveryIndex + 1}: $lat, $lng');
```

### Test Data Generation
```dart
Future<void> _generateTestOrders() async {
  const String testMealId = 'oncBK7euW3Guom4rD8Rt';
  
  final testCustomers = [
    {
      'name': 'Test Customer 1',
      'phone': '+60123456789',
      'address': 'Test Address 1, Kuala Lumpur',
      'lat': 3.2050,
      'lng': 101.7390,
    },
    // More test customers...
  ];
  
  // Generate orders and order items with proper schema
  for (int i = 0; i < testCustomers.length; i++) {
    // Create order
    // Create order_items with: meal_id, order_id, quantity, subtotal
  }
}
```

### Error Simulation
```dart
// Simulate network failure for testing retry logic
if (orderItemsRetryCount == 2) {
  throw Exception('Simulated network error');
}
```

---

## Performance Optimization

### Route Optimization
```dart
// Nearest neighbor algorithm for delivery optimization
static List<LatLng> optimizeRoute(LatLng start, List<LatLng> destinations) {
  List<LatLng> optimized = [start];
  List<LatLng> remaining = List.from(destinations);
  LatLng current = start;
  
  while (remaining.isNotEmpty) {
    double minDistance = double.infinity;
    int nearestIndex = 0;
    
    for (int i = 0; i < remaining.length; i++) {
      double distance = calculateDistance(current, remaining[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    
    current = remaining[nearestIndex];
    optimized.add(current);
    remaining.removeAt(nearestIndex);
  }
  
  return optimized;
}
```

### Memory Management
```dart
@override
void dispose() {
  _messageController.dispose();
  _scrollController.dispose();
  super.dispose();
}
```

### Batch Operations
```dart
Future<void> _updateAllOrdersToDelivering() async {
  final batch = FirebaseFirestore.instance.batch();
  
  for (var delivery in deliveries) {
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(delivery.id);
    
    batch.update(orderRef, {
      'status': 'delivering',
      'pickup_time': Timestamp.now(),
      'updated_at': Timestamp.now(),
    });
  }
  
  await batch.commit();
}
```

---

## Security Considerations

### Data Validation
```dart
// Validate order data before processing
if (delivery.id.isEmpty || 
    delivery.latitude == null || 
    delivery.longitude == null) {
  print('Invalid delivery data, skipping...');
  continue;
}
```

### Permission Checks
```dart
// Ensure driver has necessary permissions
if (currentUser?.role != 'driver') {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Access denied: Driver role required'),
      backgroundColor: Colors.red,
    ),
  );
  return;
}
```

### Location Privacy
```dart
// Only share location during active deliveries
if (currentStatus == 'All Deliveries Complete') {
  // Stop location sharing
  await _stopLocationSharing();
}
```

---

## Integration Points

### Main App Integration
```dart
// In main.dart - Driver role detection
Future<void> _requestDriverLocationPermission() async {
  bool hasPermission = await LocationService.hasLocationPermission();
  if (!hasPermission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission Required'),
        content: Text('Drivers need location access for delivery tracking.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await LocationService.requestLocationPermission();
            },
            child: Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}
```

### Navigation Integration
```dart
// Navigate to driver home
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => DriverHomePage()),
);
```

---

## Troubleshooting Guide

### Common Issues

1. **Location Permission Denied**
   - Check device settings
   - Request permission in app
   - Handle permission denied gracefully

2. **Route Generation Fails**
   - Multiple OSRM server fallbacks
   - Direct route generation as backup
   - Network timeout handling

3. **Order Items Not Loading**
   - Retry mechanism (up to 5 attempts)
   - Manual retry option
   - Clear error messages

4. **Chat Room Not Found**
   - Automatic chat room creation
   - Proper participant management
   - Error handling for chat failures

5. **Status Update Failures**
   - Firebase error handling
   - Retry mechanisms
   - User feedback on failures

### Debug Commands
```bash
# Flutter debug
flutter doctor
flutter clean
flutter packages get

# Firebase debug
firebase functions:log
firebase firestore:indexes

# Location debug (Android)
adb shell settings put secure location_providers_allowed +gps
```

---

## Future Enhancements

### Planned Features
1. **Real-time GPS Tracking**: Continuous location updates
2. **Push Notifications**: Order status notifications
3. **Offline Support**: Local data caching
4. **Analytics**: Delivery performance metrics
5. **Multi-language Support**: Internationalization
6. **Driver Ratings**: Customer feedback system

### Architecture Improvements
1. **State Management**: Consider Provider/Riverpod
2. **Testing**: Unit and integration tests
3. **Documentation**: API documentation
4. **Monitoring**: Performance monitoring
5. **Security**: Enhanced authentication

---

## Conclusion

This comprehensive guide covers the complete MealMommy driver module implementation. The architecture emphasizes reliability, user experience, and maintainability. Key features include:

- **Robust Error Handling**: Retry mechanisms and fallbacks
- **Real-time Updates**: Live location and status tracking  
- **Optimized Performance**: Route optimization and batch operations
- **User-Friendly Interface**: Clear status indicators and feedback
- **Scalable Architecture**: Modular design for future enhancements

The implementation follows Flutter best practices and provides a solid foundation for a production-ready delivery tracking system.

---

*Generated on: August 3, 2025*  
*Version: 2.0*  
*Last Updated: Complete driver module implementation with retry logic, location management, and text-only chat integration*
