class MedicalProfileModel {
  final String bloodGroup;
  final String allergies;
  final String medications;
  final String medicalConditions;
  final bool organDonor;

  MedicalProfileModel({
    required this.bloodGroup,
    required this.allergies,
    required this.medications,
    required this.medicalConditions,
    required this.organDonor,
  });

  factory MedicalProfileModel.fromJson(Map<String, dynamic> json) {
    return MedicalProfileModel(
      bloodGroup: json['blood_group'] ?? '',
      allergies: json['allergies'] ?? '',
      medications: json['medications'] ?? '',
      medicalConditions: json['medical_conditions'] ?? '',
      organDonor: json['organ_donor'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_group': bloodGroup,
      'allergies': allergies,
      'medications': medications,
      'medical_conditions': medicalConditions,
      'organ_donor': organDonor,
    };
  }

  MedicalProfileModel copyWith({
    String? bloodGroup,
    String? allergies,
    String? medications,
    String? medicalConditions,
    bool? organDonor,
  }) {
    return MedicalProfileModel(
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      organDonor: organDonor ?? this.organDonor,
    );
  }
}
