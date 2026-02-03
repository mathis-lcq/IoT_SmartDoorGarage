import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  final StreamController<String> _messageController = 
      StreamController<String>.broadcast();
  
  Stream<String> get messageStream => _messageController.stream;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Initialize MQTT and notifications
  Future<void> init() async {
    // Initialize local notifications
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

  // Connect to MQTT broker
  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }

    try {
      final clientId = 'flutter_garage_${DateTime.now().millisecondsSinceEpoch}';
      
      print('MQTT connection...');
      print('Broker: broker.hivemq.com');
      print('Port: 1883');
      print('ClientID: $clientId');
      
      // Configuration identical to the working test
      _client = MqttServerClient('broker.hivemq.com', clientId);
      _client!.port = 1883;
      _client!.keepAlivePeriod = 60;
      _client!.logging(on: false);
      _client!.setProtocolV311();
      _client!.autoReconnect = true;
      
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _client!.connectionMessage = connMessage;

      print('Connecting...');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT Connected successfully');
        _isConnected = true;
        
        // Subscribe to garage topics
        subscribe(AppConfig.mqttTopic);              // smart_garage/status
        subscribe(AppConfig.mqttLogsTopic);          // smart_garage/logs
        subscribe(AppConfig.mqttPinsTopic);          // smart_garage/pins
        
        // Setup message listener
        _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          final message = messages[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            message.payload.message,
          );
          
          print('MQTT Message received: $payload');
          _messageController.add(payload);
          _handleMessage(messages[0].topic, payload);
        });
        
        return true;
      } else {
        print('State: ${_client!.connectionStatus!.state}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('MQTT Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from MQTT broker
  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }

  // Subscribe to a topic
  void subscribe(String topic) {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  // Publish a message
  bool publish(String topic, String message) {
    print('============ MQTT Publish ==========');
    print('Topic: $topic, ');
    print('Message: $message');
    
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } else {
      print('MQTT not connected - unable to publish');
      return false;
    }
  }
  
  // Publish a retained message (persists on broker)
  bool publishRetained(String topic, String message) {
    print('============ MQTT Publish (RETAINED) ==========');
    print('Topic: $topic');
    print('Message: $message');
    
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: true,  // Message retained on broker
      );
      return true;
    } else {
      print('MQTT not connected - unable to publish');
      return false;
    }
  }

  // Handle incoming MQTT messages
  void _handleMessage(String topic, String payload) {
    // Show local notification for important messages
    if (topic.contains('notifications')) {
      _showNotification('Smart Garage', payload);
    } else if (topic.contains('status')) {
      // Handle status updates
      if (payload.toLowerCase().contains('open')) {
        _showNotification('Garage Alert', 'Garage door opened');
      } else if (payload.toLowerCase().contains('close')) {
        _showNotification('Garage Alert', 'Garage door closed');
      }
    }
  }

  // Show local notification
  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'mqtt_channel',
      'MQTT Notifications',
      channelDescription: 'Notifications from MQTT broker',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,  // Show notification even when app is in foreground
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  // Callbacks
  void _onConnected() {
    print('MQTT Connected callback');
    _isConnected = true;
  }

  void _onDisconnected() {
    print('MQTT Disconnected callback');
    print('State connection: ${_client?.connectionStatus?.state}');
    print('Return code: ${_client?.connectionStatus?.returnCode}');
    _isConnected = false;
  }

  void _onSubscribed(String topic) {
    print('Subscribed to: $topic');
  }

  void dispose() {
    _messageController.close();
    disconnect();
  }
}
