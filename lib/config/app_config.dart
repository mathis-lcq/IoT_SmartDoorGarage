class AppConfig {
  // MQTT Configuration
  static const String mqttBroker = 'broker.hivemq.com'; // Change to your MQTT broker
  static const int mqttPort = 8000; // WebSocket port for HiveMQ
  static const String mqttStatusTopic = 'smart_garage/status';
  static const String mqttCommandTopic = 'smart_garage/command';
  static const String mqttLogsTopic = 'smart_garage/logs';
  static const String mqttPinsTopic = 'smart_garage/pins';
  
  // Geofencing Configuration
  static const double garageLatitude = 37.785834; // Change to your garage location
  static const double garageLongitude = -122.406417;
  static const double geofenceRadius = 100.0; // meters
  
  // App Settings
  static const String appName = 'Smart Garage';
}
