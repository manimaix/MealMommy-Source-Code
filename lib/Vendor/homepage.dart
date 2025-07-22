import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mealmommy_application/firebase_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await FirebaseService.getField(
      collection: 'User',
      docId: 'U0002',
      field: 'name',
    );

    setState(() {
      userName = name ?? 'Unknown User';
    });
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              child: SvgPicture.asset(
                'assets/icons/notification.svg', // Make sure this exists in your assets
                width: 24,
                height: 24,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: ListView(
          children: [
            Text(
              "Welcome back, $userName!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text("Ready to serve your customers today?"),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
