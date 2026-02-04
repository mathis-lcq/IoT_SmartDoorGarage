class ActivityLog {
  final String id;
  final String message; // "open", "close", "toggle"
  final String source; // username
  final String type; // "auto" (geofencing) or "manual" (button click)
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.message,
    required this.source,
    required this.type,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      message: json['message'] ?? '',
      source: json['source'] ?? 'Unknown',
      type: json['type'] ?? 'manual',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'source': source,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
