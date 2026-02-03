import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/mqtt_service.dart';
import '../config/app_config.dart';

class AuthProvider with ChangeNotifier {
  final MqttService _mqttService;
  bool _isAuthenticated = false;
  String? _currentPin;
  bool _isAdmin = false;
  List<String> _validPins = ['666666']; // Default admin PIN

  AuthProvider(this._mqttService);

  bool get isAuthenticated => _isAuthenticated;
  String? get currentPin => _currentPin;
  bool get isAdmin => _isAdmin;
  List<String> get validPins => List.unmodifiable(_validPins.where((pin) => pin != '666666'));

  // Initialize - check if user is already logged in
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPin = prefs.getString('current_pin');
    _isAuthenticated = _currentPin != null;
    _isAdmin = _currentPin == '666666';
    
    // Load local PINs (fallback)
    final savedPins = prefs.getStringList('valid_pins');
    if (savedPins != null) {
      _validPins = ['666666', ...savedPins];
    }
    
    // Subscribe to MQTT PINs updates
    _mqttService.messageStream.listen((message) {
      _handleMqttPinsUpdate(message);
    });
    
    notifyListeners();
  }

  Future<bool> loginWithPin(String pin) async {
    // Check the format
    if (pin.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return false;
    }

    // Check if the PIN is valid
    if (_validPins.contains(pin)) {
      _currentPin = pin;
      _isAuthenticated = true;
      _isAdmin = pin == '666666';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_pin', pin);

      notifyListeners();
      return true;
    }
    
    return false;
  }

  Future<bool> addPin(String pin) async {
    if (!_isAdmin) return false;
    
    // Check the format
    if (pin.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return false;
    }
    
    // Check if the PIN already exists
    if (_validPins.contains(pin)) {
      return false;
    }
    
    _validPins.add(pin);
    await _savePins();
    notifyListeners();
    return true;
  }

  Future<bool> removePin(String pin) async {
    if (!_isAdmin || pin == '666666') return false;
    
    _validPins.remove(pin);
    await _savePins();
    notifyListeners();
    return true;
  }

  void _handleMqttPinsUpdate(String message) {
    try {
      final data = jsonDecode(message);
      if (data['pins'] != null) {
        final receivedPins = List<String>.from(data['pins']);
        // Always include the admin PIN
        _validPins = ['666666', ...receivedPins.where((p) => p != '666666')];
        
        // Save locally as well (fallback)
        _savePinsLocally();
        
        print('PINs synchronized: ${_validPins.length} PINs');
        notifyListeners();
      }
    } catch (e) {
      print('Error parsing MQTT pins: $e');
    }
  }
  
  Future<void> _savePins() async {
    // Sauvegarder localement
    await _savePinsLocally();
    
    // Publier sur MQTT avec retained flag
    final pinsToPublish = _validPins.where((pin) => pin != '666666').toList();
    final message = jsonEncode({'pins': pinsToPublish});
    
    final success = _mqttService.publishRetained(AppConfig.mqttPinsTopic, message);
    if (success) {
      print('PINs published on MQTT');
    } else {
      print('Failed to publish PINs on MQTT');
    }
  }
  
  Future<void> _savePinsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final pinsToSave = _validPins.where((pin) => pin != '666666').toList();
    await prefs.setStringList('valid_pins', pinsToSave);
  }

  Future<void> logout() async {
    _currentPin = null;
    _isAuthenticated = false;
    _isAdmin = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_pin');

    notifyListeners();
  }
}
