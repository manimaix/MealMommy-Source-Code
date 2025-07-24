import 'package:flutter/material.dart';

class LiveDeliveryPage extends StatefulWidget {
  const LiveDeliveryPage({super.key});

  @override
  State<LiveDeliveryPage> createState() => _LiveDeliveryPageState();
}

class _LiveDeliveryPageState extends State<LiveDeliveryPage> {
  String _deliveryStatus = 'Heading to Restaurant';
  Map<String, dynamic>? _currentDelivery;

  @override
  void initState() {
    super.initState();
    // Sample current delivery data
    _currentDelivery = {
      'orderId': 'ORD-2024-001',
      'restaurantName': 'Pizza Palace',
      'restaurantAddress': '456 Restaurant St, City',
      'customerName': 'John Doe',
      'customerAddress': '123 Main St, Apt 4B, City',
      'customerPhone': '+1-555-0123',
      'estimatedTime': '25 min',
      'totalAmount': '\$32.50',
      'deliveryFee': '\$8.50',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Delivery'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _callCustomer,
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _openChat,
          ),
        ],
      ),
      body: _currentDelivery == null
          ? _buildNoActiveDelivery()
          : Column(
              children: [
                // Delivery Status Banner
                _buildStatusBanner(),
                
                // Google Maps Placeholder
                _buildMapPlaceholder(),
                
                // Delivery Details Card
                _buildDeliveryDetails(),
                
                // Action Buttons
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildNoActiveDelivery() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delivery_dining,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Delivery',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accept a task to start live delivery tracking',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/driver/tasks');
            },
            icon: const Icon(Icons.assignment),
            label: const Text('View Available Tasks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: Colors.green[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deliveryStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ETA: ${_currentDelivery!['estimatedTime']}',
                      style: TextStyle(
                        color: Colors.green[100],
                        fontSize: 14,
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

  Widget _buildMapPlaceholder() {
    return Expanded(
      flex: 3,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Google Maps Will Be Here',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Live location tracking and navigation',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Order ${_currentDelivery!['orderId']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Restaurant Info
              _buildInfoRow(
                Icons.restaurant,
                'Restaurant',
                _currentDelivery!['restaurantName'],
                _currentDelivery!['restaurantAddress'],
                Colors.orange,
              ),
              
              const Divider(height: 24),
              
              // Customer Info
              _buildInfoRow(
                Icons.person,
                'Customer',
                _currentDelivery!['customerName'],
                _currentDelivery!['customerAddress'],
                Colors.green,
              ),
              
              const SizedBox(height: 16),
              
              // Payment Info
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Fee: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _currentDelivery!['deliveryFee'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Total: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _currentDelivery!['totalAmount'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String name, String address, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Live Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateDeliveryStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _getNextStatusButton(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_deliveryStatus) {
      case 'Heading to Restaurant':
        return Icons.restaurant;
      case 'Picking up Order':
        return Icons.shopping_bag;
      case 'On the Way':
        return Icons.delivery_dining;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.delivery_dining;
    }
  }

  String _getNextStatusButton() {
    switch (_deliveryStatus) {
      case 'Heading to Restaurant':
        return 'Mark: Arrived at Restaurant';
      case 'Picking up Order':
        return 'Mark: Order Picked Up';
      case 'On the Way':
        return 'Mark: Order Delivered';
      case 'Delivered':
        return 'Complete Delivery';
      default:
        return 'Update Status';
    }
  }

  void _updateDeliveryStatus() {
    setState(() {
      switch (_deliveryStatus) {
        case 'Heading to Restaurant':
          _deliveryStatus = 'Picking up Order';
          break;
        case 'Picking up Order':
          _deliveryStatus = 'On the Way';
          break;
        case 'On the Way':
          _deliveryStatus = 'Delivered';
          break;
        case 'Delivered':
          _completeDelivery();
          break;
      }
    });
  }

  void _completeDelivery() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delivery Complete!'),
          content: const Text('Great job! The delivery has been completed successfully.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentDelivery = null;
                  _deliveryStatus = 'Heading to Restaurant';
                });
                Navigator.of(context).pop(); // Go back to driver home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _callCustomer() {
    // Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${_currentDelivery!['customerPhone']}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openChat() {
    // Navigate to chat screen
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.chat, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Chat with ${_currentDelivery!['customerName']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Live chat functionality will be implemented here.\n\nFeatures:\n• Real-time messaging\n• Delivery updates\n• Photo sharing\n• Quick responses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
