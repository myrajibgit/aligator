import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolModel {
  final String id;
  final String name;
  final String city;
  final String state;
  final String country;
  final String? domain;
  final bool verified;
  final String status;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    this.domain,
    this.verified = false,
    required this.status,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      domain: json['domain'] as String?,
      verified: (json['verified'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'active',
    );
  }

  factory SchoolModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SchoolModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'state': state,
      'country': country,
      if (domain != null) 'domain': domain,
      'verified': verified,
      'status': status,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('id');
  }

  SchoolModel copyWith({
    String? id,
    String? name,
    String? city,
    String? state,
    String? country,
    String? domain,
    bool? verified,
    String? status,
  }) {
    return SchoolModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      domain: domain ?? this.domain,
      verified: verified ?? this.verified,
      status: status ?? this.status,
    );
  }
}
