import 'package:cloud_firestore/cloud_firestore.dart';

class SiteModel {
  final String id;
  final String name;
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SiteModel({
    required this.id,
    required this.name,
    required this.location,
    this.createdAt,
    this.updatedAt,
  });

  factory SiteModel.fromMap(String id, Map<String, dynamic> data) {
    return SiteModel(
      id: id,
      name: (data['name'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    return {
      'name': name,
      'location': location,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
