import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../customer/customer_home.dart';
import '../vendor/vendor_home.dart';
import '../driver/driver_home.dart';
import '../main.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.userStream,
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Debug: Print user role
          print('AuthWrapper: User role is "${user.role}"');
          
          // Route based on user role
          switch (user.role.toLowerCase()) {
            case 'customer':
              print('AuthWrapper: Routing to CustomerHome');
              return const CustomerHome();
            case 'vendor':
              print('AuthWrapper: Routing to VendorHome');
              return const VendorHome();
            case 'driver':
              print('AuthWrapper: Routing to DriverHome');
              return const DriverHome();
            default:
              // Default to customer if role is not recognized
              print('AuthWrapper: Unknown role "${user.role}", defaulting to CustomerHome');
              return const CustomerHome();
          }
        } else {
          // User is not logged in, show login page
          return const LoginPage();
        }
      },
    );
  }
}
