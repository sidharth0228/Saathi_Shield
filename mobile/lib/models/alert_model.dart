class AlertModel {
  final String alertId;
  final String secureToken;
  final String trackingUrl;
  final String message;

  AlertModel({
    required this.alertId,
    required this.secureToken,
    required this.trackingUrl,
    required this.message,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      alertId: json['alert_id'] ?? '',
      secureToken: json['secure_token'] ?? '',
      trackingUrl: json['tracking_url'] ?? '',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_id': alertId,
      'secure_token': secureToken,
      'tracking_url': trackingUrl,
      'message': message,
    };
  }
}
