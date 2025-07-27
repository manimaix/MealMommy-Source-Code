import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LatLng> _locationController = StreamController<LatLng>.broadcast();
  LatLng? _currentLocation;
  bool _isTracking = false;

  /// Stream of location updates
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Get current location (may be null if not available)
  LatLng? get currentLocation => _currentLocation;

  /// Check if location services are enabled and permissions are granted
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permissions
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position once
  static Future<LatLng?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw PermissionDeniedException('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw PermissionDeniedException('Location permissions are permanently denied');
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Start tracking location with continuous updates
  Future<bool> startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // meters
    Duration? timeInterval,
  }) async {
    if (_isTracking) {
      print('Location tracking is already active');
      return true;
    }

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return false;
      }

      // Start position stream
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationController.add(_currentLocation!);
          print('Location updated: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          print('Location stream error: $error');
        },
      );

      _isTracking = true;
      print('Location tracking started');
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    print('Location tracking stopped');
  }

  /// Get distance between two points
  static double getDistanceBetween(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Get bearing between two points
  static double getBearingBetween(LatLng point1, LatLng point2) {
    return Geolocator.bearingBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Default location (Kuala Lumpur) as fallback
  static LatLng get defaultLocation => LatLng(3.139, 101.6869);

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _locationController.close();
  }

  /// Get location with timeout and fallback
  static Future<LatLng> getLocationWithFallback({
    Duration timeout = const Duration(seconds: 10),
    LatLng? fallbackLocation,
  }) async {
    try {
      final location = await getCurrentPosition().timeout(timeout);
      return location ?? fallbackLocation ?? defaultLocation;
    } catch (e) {
      print('Location timeout or error, using fallback: $e');
      return fallbackLocation ?? defaultLocation;
    }
  }

  /// Request location permission with user-friendly messages
  static Future<LocationPermissionResult> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult(
          granted: false,
          message: 'Location services are disabled. Please enable them in your device settings.',
          canRequestAgain: false,
        );
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionResult(
            granted: true,
            message: 'Location permission granted',
            canRequestAgain: false,
          );
        case LocationPermission.denied:
          return LocationPermissionResult(
            granted: false,
            message: 'Location permission denied. Location features will be limited.',
            canRequestAgain: true,
          );
        case LocationPermission.deniedForever:
          return LocationPermissionResult(
            granted: false,
            message: 'Location permission permanently denied. Please enable it in app settings.',
            canRequestAgain: false,
          );
        case LocationPermission.unableToDetermine:
          return LocationPermissionResult(
            granted: false,
            message: 'Unable to determine location permission status.',
            canRequestAgain: true,
          );
      }
    } catch (e) {
      return LocationPermissionResult(
        granted: false,
        message: 'Error requesting location permission: $e',
        canRequestAgain: true,
      );
    }
  }

  /// Open app settings for location permission
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('Error opening location settings: $e');
      return false;
    }
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      print('Error opening app settings: $e');
      return false;
    }
  }
}

/// Result class for location permission requests
class LocationPermissionResult {
  final bool granted;
  final String message;
  final bool canRequestAgain;

  LocationPermissionResult({
    required this.granted,
    required this.message,
    required this.canRequestAgain,
  });
}

/// Custom exceptions for location services
class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException([this.message = 'Location services are disabled']);
  
  @override
  String toString() => 'LocationServiceDisabledException: $message';
}

class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException([this.message = 'Location permission denied']);
  
  @override
  String toString() => 'PermissionDeniedException: $message';
}
