# Smart Garage App 🚪

A Flutter mobile application for GPS-based geofencing and secure remote control of garage doors via MQTT.

## Architecture

```
Mobile App (Flutter)
       |
    MQTT Broker (broker.hivemq.com)
       |
   ESP8266 → Garage Door Motor
```

## Features

- **User Authentication**: Simple login/register system
- **Remote Control**: Open/Close garage door buttons
- **Real-time Status**: Live garage door status monitoring via MQTT
- **Geofencing**: Automatic GPS-based location monitoring
- **MQTT Publisher/Subscriber**: Real-time notifications and status updates
- **Push Notifications**: Local alerts when garage opens/closes
- **Activity Logs**: Complete history of all garage events
- **User Management**: Add/remove users with access
- **Background Monitoring**: Continuous geofence monitoring

## Getting Started

### Prerequisites

- Flutter SDK (3.10.7 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- ESP8266 with MQTT

### Installation

1. **Clone the repository**
   ```bash
   cd smart_garage_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure your ESP8266 IP and settings**
   
   Edit `lib/config/app_config.dart`:
   ```dart
   static const double garageLatitude = 37.7749; // Your garage latitude
   static const double garageLongitude = -122.4194; // Your garage longitude
   static const double geofenceRadius = 100.0; // Radius in meters
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Required ESP8266 MQTT Topics

Your ESP8266 should subscribe and publish to these MQTT topics:

### Subscribe to (ESP8266 receives commands):
- `smart_garage/command` - Receives door control commands

### Publish to (ESP8266 sends updates):
- `smart_garage/status` - Door status updates
- `smart_garage/logs` - Activity log events
- `smart_garage/pins` - PIN code synchronization (retained)

### MQTT Command Format

**Commands sent to `smart_garage/command`:**
```json
{"command": "open"}
{"command": "close"}
{"command": "toggle"}
{"command": "get_status"}
```

### MQTT Response Format

**Status updates on `smart_garage/status`:**
```json
{
  "status": "open"
}
```

**Activity logs on `smart_garage/logs`:**
```json
{
  "action": "Garage Opened",
  "user": "geofence",
  "source": "mqtt"
}
```

**PIN synchronization on `smart_garage/pins` (retained):**
```json
{
  "pins": ["123456", "789012"]
}
```

## Configuration

### Android Permissions

The app requires these permissions (already configured in `AndroidManifest.xml`):
- `ACCESS_FINE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `INTERNET`
- `POST_NOTIFICATIONS`

### iOS Permissions

Location permissions are configured in `Info.plist` with proper usage descriptions.

## Project Structure

```
lib/
├── config/
│   └── app_config.dart          # App configuration
├── models/
│   ├── user.dart                # User model
│   ├── garage_status.dart       # Garage status model
│   └── activity_log.dart        # Activity log model
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   └── garage_provider.dart     # Garage state management
├── screens/
│   ├── login_screen.dart        # Login page
│   ├── register_screen.dart     # Registration page
│   ├── dashboard_screen.dart    # Main dashboard
│   └── user_management_screen.dart # User management
├── services/
│   └── geofence_service.dart     # Geofencing logic
│   └── mqtt_service.dart         # Mqtt logic
│   └── notification_service.dart # Notification logic
└── main.dart                     # App entry point
```

## Usage

### First Time Setup

1. Launch the app
2. Login with your credentials
3. Configure geofencing and grant location permissions when prompted (optional)

### Using the App

- **Manual Control**: Use OPEN/CLOSE buttons on dashboard
- **Status Monitoring**: View real-time garage status
- **Geofencing**: Enable to automatically monitor your location
- **Activity Logs**: Scroll down on dashboard to see history
- **User Management**: Tap user icon in app bar

## Troubleshooting

### Location Permissions
If geofencing doesn't work:
1. Check app permissions in phone settings
2. Ensure location services are enabled
3. Grant "Always Allow" location permission

### API Connection Issues
- Verify ESP8266 is on same network
- Check firewall settings
- Confirm correct IP address in config
- Test endpoints with Postman/curl first

### Build Issues
```bash
flutter clean
flutter pub get
flutter run
```

### Dependencies

- `provider`: State management
- `geolocator`: GPS location
- `geofence_service`: Geofencing
- `flutter_local_notifications`: Local notifications
- `shared_preferences`: Local storage
- `intl`: Date formatting
- `mqtt_client`: MQTT Publisher/Subscriber for real-time updates

## Screenshots

The app includes:
- **Login Screen**: Clean authentication UI
- **Dashboard**: Status display with control buttons
- **Activity Logs**: Scrollable event history
- **User Management**: Add/remove users

## License

This project is provided as-is for educational and personal use.
