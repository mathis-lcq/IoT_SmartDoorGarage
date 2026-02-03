import 'package:flutter/foundation.dart';
import '../models/garage_status.dart';
import '../models/activity_log.dart';
import '../services/mqtt_service.dart';
import '../config/app_config.dart';
import 'dart:async';
import 'dart:convert';

class GarageProvider with ChangeNotifier {
  final MqttService _mqttService;

  GarageStatus? _status;
  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _mqttSubscription;

  GarageProvider(this._mqttService);

  GarageStatus? get status => _status;
  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMqttConnected => _mqttService.isConnected;

  // Initialize - start listening to MQTT messages
  Future<void> init() async {
    startAutoRefresh();
  }

  // Start auto-refresh
  void startAutoRefresh() {
    // Only create subscription if it doesn't exist
    _mqttSubscription ??= _mqttService.messageStream.listen((message) {
        _handleMqttMessage(message);
      });
  }

  // Handle MQTT messages
  void _handleMqttMessage(String message) {
    try {
      final data = jsonDecode(message);

      // Update status if message contains status info
      if (data['status'] != null) {
        _status = GarageStatus(
          status: data['status'],
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
      } 

      // Add log if message contains log info 
      if (data['action'] != null) {
        final log = ActivityLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          action: data['action'],
          timestamp: DateTime.now(),
          user: data['user'] ?? 'system',
          source: data['source'] ?? 'mqtt',
        );
        _logs.insert(0, log);
        if (_logs.length > 50) {
          _logs = _logs.sublist(0, 50);
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }

  // Stop auto-refresh
  void stopAutoRefresh() {
    _mqttSubscription?.cancel();
    _mqttSubscription = null;
  }

  // Refresh garage status (manual via pull-to-refresh)
  Future<void> refreshStatus() async {
    // Request status update via MQTT
    _mqttService.publish(
      AppConfig.mqttCommandTopic,
      jsonEncode({'command': 'get_status'}),
    );
  }

  // Open garage via MQTT
  Future<bool> openGarage() async {
    print('=== openGarage ===');

    _isLoading = true;
    notifyListeners();

    try {
      final success = _mqttService.publish(
        AppConfig.mqttCommandTopic,
        jsonEncode({'command': 'open'}),
      );
      
      if (success) {
        print('OPEN command sent successfully');
      } else {
        print('Failed to send OPEN command');
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('ERROR openGarage: $e');
      _errorMessage = 'Error opening garage: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Close garage via MQTT
  Future<bool> closeGarage() async {
    print('=== closeGarage ===');

    _isLoading = true;
    notifyListeners();

    try {
      final success = _mqttService.publish(
        AppConfig.mqttCommandTopic,
        jsonEncode({'command': 'close'}),
      );
      
      if (success) {
        print('CLOSE command sent successfully');
      } else {
        print('Failed to send CLOSE command');
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('ERROR closeGarage: $e');
      _errorMessage = 'Error closing garage: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Toggle garage via MQTT
  Future<bool> toggleGarage() async {
    print('=== toggleGarage ===');
    
    _isLoading = true;
    notifyListeners();

    try {
      final success = _mqttService.publish(
        AppConfig.mqttCommandTopic,
        jsonEncode({'command': 'toggle'}),
      );
      
      if (success) {
        print('TOGGLE command sent successfully');
      } else {
        print('Failed to send TOGGLE command');
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      print('ERREUR toggleGarage: $e');
      _errorMessage = 'Error toggling garage: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
