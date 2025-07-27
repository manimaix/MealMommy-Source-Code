import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../driver/driver_revenue.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser? currentUser;
  final String title;
  final VoidCallback? onSignOut;
  final VoidCallback? onProfile;
  final List<Widget>? actions;
  final bool? isOnline;
  final VoidCallback? onToggleOnline;

  const GlobalAppBar({
    Key? key,
    this.currentUser,
    this.title = "Meal Mommy",
    this.onSignOut,
    this.onProfile,
    this.actions,
    this.isOnline,
    this.onToggleOnline,
  }) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService.instance.signOut();
      if (context.mounted) {
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
    final isDriver = currentUser?.role == 'driver';

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFFEBD4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            Image.asset('assets/icons/Logo.png', width: 40),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1.5, 1.5),
                    blurRadius: 2,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: actions ??
            [
              // Notification icon
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.of(context).pushNamed('/notification');
                },
              ),

              // Online status indicator for drivers
              if (isDriver)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: onToggleOnline,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isOnline ?? false) ? Colors.green : Colors.red,
                        border: Border.all(
                          color: (isOnline ?? false)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

              // Popup menu for vendors (all except drivers)
              if (!isDriver)
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String value) {
                    switch (value) {
                      case 'home':
                        Navigator.of(context).pushReplacementNamed('/vendor');
                        break;
                      case 'order':
                        Navigator.of(context).pushReplacementNamed('/order');
                        break;
                      case 'foodlist':
                        Navigator.of(context).pushReplacementNamed('/foodList');
                        break;
                      case 'menu':
                        Navigator.of(context).pushReplacementNamed('/menu');
                        break;
                      case 'revenue':
                        Navigator.of(context).pushReplacementNamed('/revenue');
                        break;
                      case 'cert':
                        Navigator.of(context).pushReplacementNamed('/cert');
                        break;
                      case 'profile':
                        Navigator.of(context).pushReplacementNamed('/profile');
                        break;
                      case 'logout':
                        _signOut(context);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'home', child: Text('Home')),
                    PopupMenuItem<String>(value: 'order', child: Text('Order')),
                    PopupMenuItem<String>(value: 'foodlist', child: Text('Food List')),
                    PopupMenuItem<String>(value: 'menu', child: Text('Menu')),
                    PopupMenuItem<String>(value: 'revenue', child: Text('Revenue')),
                    PopupMenuItem<String>(value: 'cert', child: Text('Certificate')),
                    PopupMenuItem<String>(value: 'profile', child: Text('Profile')),
                    PopupMenuItem<String>(value: 'logout', child: Text('Sign Out')),
                  ],
                ),

              // Popup menu for drivers
              if (isDriver)
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String value) {
                    switch (value) {
                      case 'revenue':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DriverRevenuePage(),
                          ),
                        );
                        break;
                      case 'profile':
                        if (onProfile != null) {
                          onProfile!();
                        }
                        break;
                      case 'logout':
                        _signOut(context);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'revenue',
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Revenue'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Sign Out'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
