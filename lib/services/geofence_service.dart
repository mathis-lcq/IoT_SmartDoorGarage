import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  late MqttService _mqttService = MqttService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _locationTimer;
  bool _isInsideGeofence = false;
  bool _isServiceRunning = false;
  
  // Override coordinates for testing
  double? _testLatitude;
  double? _testLongitude;
  
  // Callback to get garage status
  bool Function()? _getGarageStatus;

  // Initialize geofencing service
  Future<void> init([MqttService? mqttService]) async {
    if (mqttService != null) {
      _mqttService = mqttService;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
  }

  // Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Request background location permission
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return true;
  }

  // Set callback to get garage status
  void setGarageStatusCallback(bool Function() callback) {
    _getGarageStatus = callback;
  }
  
  // Set test coordinates
  void setTestCoordinates(double lat, double lng) {
    _testLatitude = lat;
    _testLongitude = lng;
    print('Test coordinates set');
  }
  
  // Clear test coordinates
  void clearTestCoordinates() {
    _testLatitude = null;
    _testLongitude = null;
    print('Test coordinates cleared');
  }
  
  // Start geofencing monitoring
  Future<void> startMonitoring() async {
    if (_isServiceRunning) {
      return;
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      print('❌ Location permissions denied');
      return;
    }

    _isServiceRunning = true;
    print('✅ ========== GEOFENCING STARTED ==========');
    final targetLat = _testLatitude ?? AppConfig.garageLatitude;
    final targetLng = _testLongitude ?? AppConfig.garageLongitude;
    print('🏠 Garage: $targetLat, $targetLng ${_testLatitude != null ? "(TEST)" : ""}');

    // Check location every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkGeofence();
    });

    // Initial check
    await _checkGeofence();
  }

  // Stop geofencing monitoring
  void stopMonitoring() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isServiceRunning = false;
    print('End geofencing ');
  }

  // Check if user is inside geofence
  Future<void> _checkGeofence() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final targetLat = _testLatitude ?? AppConfig.garageLatitude;
      final targetLng = _testLongitude ?? AppConfig.garageLongitude;
      
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      print('...position: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)} - distance: ${distance.toStringAsFixed(1)}m (r: ${AppConfig.geofenceRadius}m)');

      final isInside = distance <= AppConfig.geofenceRadius;

      // Trigger events on state change
      if (isInside != _isInsideGeofence) {
        _isInsideGeofence = isInside;

        if (isInside) {
          print('============== ENTRY ZONE ==============');
          await _onEnterGeofence(position.latitude, position.longitude, distance);
        } else {
          print('============== EXIT ZONE ==============');
          await _onExitGeofence(position.latitude, position.longitude, distance);
        }
      }
    } catch (e) {
      print('Geofence check error: $e');
    }
  }

  // Handle entering geofence
  Future<void> _onEnterGeofence(double lat, double lng, double distance) async {
    // Publish event via MQTT
    final geofenceEvent = jsonEncode({
      'event': 'enter',
    });
    _mqttService.publish(AppConfig.mqttLogsTopic, geofenceEvent);
    print('MQTT event published: $geofenceEvent');
    
    // Check door status
    final isOpen = _getGarageStatus?.call() ?? false;
    
    if (!isOpen) {
      print('Door CLOSED → Sending OPEN command');
      _mqttService.publish(AppConfig.mqttCommandTopic, jsonEncode({'command': 'open'}));
      NotificationService().showInApp(
        title: 'Welcome Home',
        message: 'Door opening',
        icon: Icons.lock_open,
        backgroundColor: Colors.green,
      );
    } else {
      print('Door already OPEN → No action');
      NotificationService().showInApp(
        title: 'Welcome Home',
        message: 'Door opened',
        icon: Icons.lock_open,
        backgroundColor: Colors.blue,
      );
    }
  }

  // Handle exiting geofence
  Future<void> _onExitGeofence(double lat, double lng, double distance) async {
    // Publish event via MQTT
    final geofenceEvent = jsonEncode({
      'event': 'exit',
    });
    _mqttService.publish(AppConfig.mqttLogsTopic, geofenceEvent);
    print('MQTT event published: $geofenceEvent');
    
    // Check door status
    final isOpen = _getGarageStatus?.call() ?? false;
    print('Door status: ${isOpen ? "OPEN" : "CLOSED"}');
    
    if (isOpen) {
      print('Door OPEN → Sending CLOSE command');
      _mqttService.publish(AppConfig.mqttCommandTopic, jsonEncode({'command': 'close'}));
      NotificationService().showInApp(
        title: 'Goodbye',
        message: 'Door closing',
        icon: Icons.lock,
        backgroundColor: Colors.orange,
      );
    } else {
      print('Door already CLOSED → No action');
      NotificationService().showInApp(
        title: 'Goodbye',
        message: 'Door closed',
        icon: Icons.lock,
        backgroundColor: Colors.blue,
      );
    }
  }

  bool get isRunning => _isServiceRunning;
  bool get isInsideGeofence => _isInsideGeofence;
}
