import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'models/models.dart';
import 'register_page.dart';
import 'customer/customer_home.dart';
import 'vendor/homepage.dart';
import 'driver/driver_home.dart';
import 'driver/live_delivery_page.dart';
import 'notification_page.dart';
import 'vendor/menu.dart';
import 'vendor/addmenu.dart';
import 'vendor/foodlist.dart';
import 'vendor/fooddetail.dart';
import 'Vendor/addfood.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'vendor/revenue.dart';
import 'vendor/order.dart';
import 'vendor/orderdetail.dart';
import 'vendor/editmenu.dart';
import 'vendor/editfood.dart';
import 'vendor/foodsafety.dart';
import 'models/meal_model.dart';
import 'vendor/certificate.dart';
import 'customer/user_profile.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  final notificationService = NotificationService();
  if (!kIsWeb) {
    // Only initialize notifications on mobile platforms
    await notificationService.init();
  }

  // Configure Firebase App Check based on platform
  if (kIsWeb) {
    // For web development, you can disable App Check or use a proper reCAPTCHA key
    // await FirebaseAppCheck.instance.activate(
    //   webProvider: ReCaptchaV3Provider('your-recaptcha-site-key'),
    // );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MealMommy',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/customer': (context) => const CustomerHome(),
        '/vendor': (context) => const HomePage(),
        '/driver': (context) => const DriverHome(),
        '/driver/live-delivery': (context) => const LiveDeliveryPage(),
        '/notification': (context) => const NotificationPage(),
        '/menu': (context) => const MenuListPage(),
        '/addmenu': (context) => const AddMenuPage(),
        '/foodList': (context) => const FoodListPage(),
        '/fooddetail': (context) => FoodDetailPage(
          meal: ModalRoute.of(context)!.settings.arguments as Meal,
        ),
        '/addfood': (context) => const AddFoodPage(),
        '/revenue': (context) => const RevenuePage(),
        '/order': (context) => const OrderPage(),
        '/orderdetail': (context) => const OrderDetailPage(),
        '/editmenu': (context) => EditMenuPage(
          meal: ModalRoute.of(context)!.settings.arguments as Meal,
        ),
        '/foodsafety': (context) => const FoodSafetyPage(),
        '/cert': (context) => const CertificatePage(),
        '/profile': (context) => const UserProfilePage(),
        '/editfood': (context) => EditFoodPage(
          meal: ModalRoute.of(context)!.settings.arguments as Meal,
        ),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.instance.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user.name}!')),
        );
        
        // Navigate based on user role
        switch (user.role.toLowerCase()) {
          case 'customer':
            Navigator.of(context).pushReplacementNamed('/customer');
            break;
          case 'vendor':
            Navigator.of(context).pushReplacementNamed('/vendor');
            break;
          case 'driver':
            // Request location permission for drivers before navigation
            await _requestDriverLocationPermission(user);
            break;
          default:
            // Default to customer if role is not recognized
            Navigator.of(context).pushReplacementNamed('/customer');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Request location permission for drivers and navigate to driver home
  Future<void> _requestDriverLocationPermission(AppUser user) async {
    try {
      // Request location permission
      final permissionResult = await LocationService.requestLocationPermission();
      
      if (permissionResult.granted) {
        // Permission granted, navigate to driver home
        Navigator.of(context).pushReplacementNamed('/driver');
      } else {
        // Show permission dialog
        await _showDriverLocationPermissionDialog(permissionResult, user);
      }
    } catch (e) {
      print('Error requesting driver location permission: $e');
      // Fallback: navigate to driver home anyway
      Navigator.of(context).pushReplacementNamed('/driver');
    }
  }

  // Show location permission dialog specifically for drivers
  Future<void> _showDriverLocationPermissionDialog(LocationPermissionResult result, AppUser user) async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text('Driver Location Access'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(result.message),
              const SizedBox(height: 16),
              const Text(
                'As a driver, location access is essential for:\n'
                '• Finding nearby delivery orders\n'
                '• Navigation and route planning\n'
                '• Real-time location tracking\n'
                '• Accurate distance calculations\n'
                '• Customer delivery updates',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            if (result.canRequestAgain)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Try again
                child: const Text('Try Again'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Continue anyway
              child: const Text('Continue Without Location'),
            ),
            if (!result.canRequestAgain)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  LocationService.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
          ],
        );
      },
    );

    if (shouldContinue == true) {
      // Continue to driver home even without location permission
      Navigator.of(context).pushReplacementNamed('/driver');
    } else {
      // Try requesting permission again
      await _requestDriverLocationPermission(user);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    try {
      await AuthService.instance.resetPassword(_emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icons/Logo.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to material icon if asset fails to load
                return Icon(
                  Icons.restaurant_menu,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                );
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'MealMommy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo
                  Image.asset(
                    'assets/icons/Logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to material icon if asset fails to load
                      return Icon(
                        Icons.restaurant_menu,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // Register Link
                  TextButton(
                    onPressed: _navigateToRegister,
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
