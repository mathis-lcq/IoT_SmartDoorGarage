class GarageStatus {
  final String status; // "open" or "closed"
  final DateTime lastUpdated;

  GarageStatus({
    required this.status,
    required this.lastUpdated,
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isClosed => status.toLowerCase() == 'closed';

  factory GarageStatus.fromJson(Map<String, dynamic> json) {
    return GarageStatus(
      status: json['status'] ?? 'unknown',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
