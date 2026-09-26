class TravelSessionModel {
  final String id;
  final String sourceAddress;
  final double sourceLat;
  final double sourceLng;
  final String destAddress;
  final double destLat;
  final double destLng;
  final String status; // ACTIVE, DEVIATED, SOS_TRIGGERED, COMPLETED
  final String riskLevel; // LOW, MEDIUM, HIGH
  final Map<String, dynamic>? routeGeojson;
  final int expectedDurationMinutes;
  final String? startTime;

  TravelSessionModel({
    required this.id,
    required this.sourceAddress,
    required this.sourceLat,
    required this.sourceLng,
    required this.destAddress,
    required this.destLat,
    required this.destLng,
    required this.status,
    required this.riskLevel,
    this.routeGeojson,
    required this.expectedDurationMinutes,
    this.startTime,
  });

  factory TravelSessionModel.fromJson(Map<String, dynamic> json) {
    return TravelSessionModel(
      id: json['id'] ?? '',
      sourceAddress: json['source_address'] ?? '',
      sourceLat: double.tryParse(json['source_lat']?.toString() ?? '') ?? 0.0,
      sourceLng: double.tryParse(json['source_lng']?.toString() ?? '') ?? 0.0,
      destAddress: json['dest_address'] ?? '',
      destLat: double.tryParse(json['dest_lat']?.toString() ?? '') ?? 0.0,
      destLng: double.tryParse(json['dest_lng']?.toString() ?? '') ?? 0.0,
      status: json['status'] ?? 'ACTIVE',
      riskLevel: json['risk_level'] ?? 'LOW',
      routeGeojson: json['route_geojson'],
      expectedDurationMinutes: json['expected_duration_minutes'] ?? 0,
      startTime: json['start_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_address': sourceAddress,
      'source_lat': sourceLat.toString(),
      'source_lng': sourceLng.toString(),
      'dest_address': destAddress,
      'dest_lat': destLat.toString(),
      'dest_lng': destLng.toString(),
      'status': status,
      'risk_level': riskLevel,
      'route_geojson': routeGeojson,
      'expected_duration_minutes': expectedDurationMinutes,
      'start_time': startTime,
    };
  }
}
