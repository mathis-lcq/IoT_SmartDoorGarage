class ActivityLog {
  final String id;
  final String action;
  final String user;
  final DateTime timestamp;
  final String? source; // "manual", "geofence", "schedule"

  ActivityLog({
    required this.id,
    required this.action,
    required this.user,
    required this.timestamp,
    this.source,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      user: json['user'] ?? 'Unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'user': user,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
    };
  }
}
