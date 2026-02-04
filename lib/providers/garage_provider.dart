import 'package:flutter/foundation.dart';
import '../models/garage_status.dart';
import '../models/activity_log.dart';
import '../services/mqtt_service.dart';
import '../services/database_service.dart';
import '../config/app_config.dart';
import 'dart:async';
import 'dart:convert';

class GarageProvider with ChangeNotifier {
  final MqttService _mqttService;
  final DatabaseService _dbService = DatabaseService();

  GarageStatus? _status;
  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  StreamSubscription? _mqttSubscription;

  GarageProvider(this._mqttService);

  GarageStatus? get status => _status;
  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;
  bool get isMqttConnected => _mqttService.isConnected;

  // Initialize - start listening to MQTT messages
  Future<void> init() async {
    // Load logs from database
    await _loadLogsFromDatabase();
    startAutoRefresh();
  }

  // Load logs from database
  Future<void> _loadLogsFromDatabase() async {
    try {
      _logs = await _dbService.getAllLogs(limit: 50);
      notifyListeners();
    } catch (e) {
      print('Error loading logs from database: $e');
    }
  }

  // Start auto-refresh
  void startAutoRefresh() {
    // Only create subscription if it doesn't exist
    _mqttSubscription ??= _mqttService.messageStream.listen((mqttMessage) {
        // Filter only status and logs topics
        if (mqttMessage.topic == AppConfig.mqttStatusTopic) {
          _handleMqttMessageStatus(mqttMessage.payload);
        } else if (mqttMessage.topic == AppConfig.mqttLogsTopic) {
          _handleMqttMessageLogs(mqttMessage.payload);
        }
      });
  }

  // Handle MQTT messages
  void _handleMqttMessageStatus(String message) {
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
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }

  void _handleMqttMessageLogs(String message) {
    try {
      final data = jsonDecode(message);

      // Add log if message contains log info 
      if (data['message'] != null) {
        final log = ActivityLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: data['message'] ?? '',
          source: data['source'] ?? 'unknown',
          type: data['type'] ?? 'manual',
          timestamp: DateTime.now(),
        );
        
        // Save to database
        _dbService.insertLog(log);
        
        // Add to memory list
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
  Future<bool> openGarage({String username = 'unknown'}) async {
    print('=== openGarage ===');

    _isLoading = true;
    notifyListeners();

    try {
      final success = _mqttService.publish(
        AppConfig.mqttCommandTopic,
        jsonEncode({'command': 'open', 'source': username, 'type': 'manual'}),
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
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Close garage via MQTT
  Future<bool> closeGarage({String username = 'unknown'}) async {
    print('=== closeGarage ===');

    _isLoading = true;
    notifyListeners();

    try {
      final success = _mqttService.publish(
        AppConfig.mqttCommandTopic,
        jsonEncode({'command': 'close', 'source': username, 'type': 'manual'}),
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
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
