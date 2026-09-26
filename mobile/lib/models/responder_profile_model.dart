class ResponderProfileModel {
  final String id;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool privacyShareLocation;

  ResponderProfileModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.privacyShareLocation,
  });

  factory ResponderProfileModel.fromJson(Map<String, dynamic> json) {
    return ResponderProfileModel(
      id: json['id']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
      isAvailable: json['is_available'] ?? false,
      privacyShareLocation: json['privacy_share_location'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'is_available': isAvailable,
      'privacy_share_location': privacyShareLocation,
    };
  }
}
