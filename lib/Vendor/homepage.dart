import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2; 
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.instance.getCurrentUserData();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading user: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset('assets/icons/Logo.png', width: 40), // Your logo
            SizedBox(width: 10), // Space between logo and text
            Text(
              'Meal Mommy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          
          ],
        ),
        elevation: 0.0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).pushNamed('/notification');
            },
          ),
          // IconButton(
          //   icon: CircleAvatar(
          //     backgroundImage: _currentUser?.profilePicture != null
          //         ? NetworkImage(_currentUser!.profilePicture!)
          //         : AssetImage('assets/icons/Logo.png') as ImageProvider,
          //   ),
          //   onPressed: () {
          //     // Navigate to profile page or show profile options
          //   },
          //   tooltip: 'Profile',
          // ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: ListView(
                children: [
                  Text(
                    "Welcome back, ${_currentUser?.name ?? 'Vendor'}!",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text("Ready to serve your customers today?"),
                  SizedBox(height: 20),

                  Text("Orders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  _buildOrderCard("Order #001", "2x Nasi Lemak, 1x Teh Tarik"),
                  _buildOrderCard("Order #002", "1x Roti Canai, 1x Milo"),
                  _buildOrderCard("Order #003", "3x Chicken Rice"),
                  SizedBox(height: 20),

                  /// Menu of the Day Section
                  Text("Menu of the Day", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  _buildMenuCard("Nasi Lemak", "With egg, anchovies, and sambal"),
                  _buildMenuCard("Mee Goreng", "Spicy fried noodles"),
                  _buildAddMenuCard(),
                ],
              ),
            ),

        bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "Food List"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Menu"),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: "Rating"),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.of(context).pushNamed('/orders');
              break;
            case 1:
              Navigator.of(context).pushNamed('/foodList');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/vendor');
              break;
            case 3:
              Navigator.of(context).pushNamed('/menu');
              break;
            case 4:
              Navigator.of(context).pushNamed('/review');
              break;
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(String title, String details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(title),
        subtitle: Text(details),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildMenuCard(String name, String description) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(name),
        subtitle: Text(description),
      ),
    );
  }

Widget _buildAddMenuCard() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedIndex = 2; 
        });
        Navigator.of(context).pushNamed('/menu');
      },
      child: SizedBox(
        height: 60, // same height as ListTile
        child: Center(
          child: Icon(Icons.add_circle, color: Colors.blue, size: 36),
        ),
      ),
    ),
  );
}


}
