import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({Key? key, this.title = "Meal Mommy"}) : super(key: key);

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
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFFEBD4),
        elevation: 0, // Elevation handled by Material above
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
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/notification');
            },
          ),
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
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
