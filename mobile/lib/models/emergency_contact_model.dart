class EmergencyContactModel {
  final String? id;
  final String name;
  final String relationship;
  final String phone;
  final String? email;
  final bool notifySms;
  final bool notifyEmail;
  final bool notifyPush;
  final int priority;

  EmergencyContactModel({
    this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
    this.notifySms = true,
    this.notifyEmail = true,
    this.notifyPush = true,
    required this.priority,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      notifySms: json['notify_sms'] ?? true,
      notifyEmail: json['notify_email'] ?? true,
      notifyPush: json['notify_push'] ?? true,
      priority: json['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'notify_sms': notifySms,
      'notify_email': notifyEmail,
      'notify_push': notifyPush,
      'priority': priority,
    };
    if (id != null) {
      data['id'] = id;
    }
    if (email != null) {
      data['email'] = email;
    }
    return data;
  }

  EmergencyContactModel copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? notifySms,
    bool? notifyEmail,
    bool? notifyPush,
    int? priority,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notifySms: notifySms ?? this.notifySms,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyPush: notifyPush ?? this.notifyPush,
      priority: priority ?? this.priority,
    );
  }
}
