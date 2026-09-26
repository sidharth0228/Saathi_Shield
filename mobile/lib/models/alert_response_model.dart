class AlertResponseModel {
  final String id;
  final String alertId;
  final String responderId;
  final String responderName;
  final String responderPhone;
  final String status; // ACCEPTED, EN_ROUTE, ARRIVED, COMPLETED, CANCELLED
  final double? responderLat;
  final double? responderLng;
  final String? acceptedAt;
  final String? arrivedAt;
  final String? completedAt;

  AlertResponseModel({
    required this.id,
    required this.alertId,
    required this.responderId,
    required this.responderName,
    required this.responderPhone,
    required this.status,
    this.responderLat,
    this.responderLng,
    this.acceptedAt,
    this.arrivedAt,
    this.completedAt,
  });

  factory AlertResponseModel.fromJson(Map<String, dynamic> json) {
    final resp = json['responder'] ?? {};
    return AlertResponseModel(
      id: json['id']?.toString() ?? '',
      alertId: json['alert']?.toString() ?? '',
      responderId: resp['id']?.toString() ?? '',
      responderName: resp['first_name'] != null 
          ? "${resp['first_name']} ${resp['last_name'] ?? ''}".trim()
          : 'Responder',
      responderPhone: resp['phone']?.toString() ?? '',
      status: json['status'] ?? 'ACCEPTED',
      responderLat: double.tryParse(json['responder_lat']?.toString() ?? ''),
      responderLng: double.tryParse(json['responder_lng']?.toString() ?? ''),
      acceptedAt: json['accepted_at'],
      arrivedAt: json['arrived_at'],
      completedAt: json['completed_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alert': alertId,
      'status': status,
      'responder_lat': responderLat,
      'responder_lng': responderLng,
      'accepted_at': acceptedAt,
      'arrived_at': arrivedAt,
      'completed_at': completedAt,
    };
  }
}
