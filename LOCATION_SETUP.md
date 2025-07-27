# Location Services Setup for MealMommy Driver App

This document explains how location services are implemented and configured for the MealMommy driver application across different platforms.

## Features

- ✅ Real-time location tracking for drivers
- ✅ Cross-platform support (Android, iOS, Web)
- ✅ Permission handling with user-friendly dialogs
- ✅ Fallback to default location if GPS unavailable
- ✅ Location status indicators in the UI
- ✅ Manual location refresh capability
- ✅ Background location tracking for active deliveries

## Implementation

### LocationService (`lib/services/location_service.dart`)
- Singleton service for managing location functionality
- Supports both one-time position requests and continuous tracking
- Handles permission requests with detailed user feedback
- Provides fallback mechanisms for better reliability

### Driver Home Integration
- Location status indicator in the app bar
- Real-time location coordinates display
- Manual location refresh button
- Automatic location updates during navigation

## Platform Configurations

### Android (`android/app/src/main/AndroidManifest.xml`)
Required permissions added:
```xml
<!-- Location permissions for driver tracking -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- Required for background location access on Android 10+ -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS (`ios/Runner/Info.plist`)
Required usage descriptions added:
```xml
<!-- Location permissions for driver tracking -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track driver position for delivery navigation and finding nearby orders.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to track driver position for delivery navigation and finding nearby orders.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs background location access to track driver position during active deliveries.</string>
```

### Web
Web platform location services work automatically using the browser's Geolocation API. No additional configuration required.

## Usage

### Basic Location Tracking
```dart
// Start location tracking
final started = await LocationService.instance.startLocationTracking();

// Listen to location updates
LocationService.instance.locationStream.listen((LatLng location) {
  print('New location: ${location.latitude}, ${location.longitude}');
});

// Get current location once
final location = await LocationService.getCurrentPosition();

// Stop tracking
LocationService.instance.stopLocationTracking();
```

### Permission Handling
```dart
// Request permissions with user-friendly messages
final result = await LocationService.requestLocationPermission();
if (result.granted) {
  // Permission granted, start tracking
} else {
  // Show appropriate message to user
  print(result.message);
}
```

### Fallback Location
```dart
// Get location with fallback
final location = await LocationService.getLocationWithFallback(
  timeout: Duration(seconds: 10),
  fallbackLocation: LatLng(3.139, 101.6869), // Kuala Lumpur
);
```

## UI Components

### Location Status Indicator
Shows current location tracking status in the app bar:
- 🟢 **Live Tracking**: GPS is active and updating
- 🟠 **Searching**: Trying to get location
- 🔴 **No Permission**: Location access denied

### Location Info Display
Shows current coordinates and tracking status in the orders panel.

### Manual Refresh
Blue location button in the app bar allows manual location updates.

## Error Handling

The app gracefully handles various location-related errors:

1. **Location Services Disabled**: Guides user to enable location services
2. **Permission Denied**: Shows informative dialog with retry options
3. **Permission Permanently Denied**: Directs user to app settings
4. **GPS Timeout**: Falls back to default location
5. **Network Issues**: Uses cached location or fallback

## Best Practices

1. **Battery Optimization**: Location tracking stops when not needed
2. **Accuracy Settings**: Uses high accuracy for better navigation
3. **Distance Filter**: Only updates when driver moves significantly (10+ meters)
4. **Graceful Degradation**: App works even without GPS access
5. **User Feedback**: Clear status indicators and error messages

## Testing

### Android Testing
1. Enable "Mock location app" in Developer Options
2. Use apps like "Fake GPS location" for testing different locations
3. Test permission flows by denying/granting location access

### iOS Simulator Testing
1. Go to Features > Location > Custom Location
2. Enter test coordinates for simulation
3. Test different location scenarios

### Web Testing
1. Use browser developer tools to simulate different locations
2. Test permission blocking/allowing scenarios
3. Verify fallback behavior when geolocation fails

## Troubleshooting

### Common Issues

1. **Location not updating on Android**
   - Check if location services are enabled
   - Ensure app has location permission
   - Verify GPS signal strength

2. **Permission denied on iOS**
   - Check Info.plist for proper usage descriptions
   - Verify app hasn't been permanently denied location access
   - Reset location permissions in iOS Settings if needed

3. **Web location not working**
   - Ensure HTTPS is used (location API requires secure context)
   - Check browser console for permission errors
   - Verify user clicked "Allow" when prompted

### Debug Information

The LocationService provides detailed logging:
- Permission request results
- Location update events
- Error conditions and fallbacks
- Tracking start/stop events

Monitor the debug console for location-related messages during development.

## Future Enhancements

Potential improvements for the location system:

1. **Geofencing**: Detect when driver arrives at pickup/delivery locations
2. **Route Optimization**: Use real-time traffic data for better routing
3. **Battery Optimization**: Adaptive location update frequency
4. **Offline Maps**: Cache map data for areas with poor connectivity
5. **Location History**: Track delivery routes for analysis
6. **Driver Analytics**: Monitor driver performance and efficiency

## Dependencies

The location functionality uses the following packages:

- `geolocator: ^13.0.2` - Core location services
- `latlong2: ^0.9.1` - Geographic coordinate handling
- `permission_handler: ^12.0.1` - Permission management (already included)

All dependencies are already configured in `pubspec.yaml`.
