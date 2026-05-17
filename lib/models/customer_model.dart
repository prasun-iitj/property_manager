import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String name;
  final String phone;
  final int totalPrice;
  final int totalPaid;
  final int remaining;
  final int emiDay;
  final DateTime? nextEmiDate;
  final String? aadharUrl;

  const CustomerModel({
    required this.name,
    required this.phone,
    required this.totalPrice,
    required this.totalPaid,
    required this.remaining,
    required this.emiDay,
    this.nextEmiDate,
    this.aadharUrl,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> data) {
    final totalPrice = _asInt(data['totalPrice']);
    final totalPaid = _asInt(data['totalPaid']);
    final remainingFromDb = _asInt(data['remaining']);

    return CustomerModel(
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      totalPrice: totalPrice,
      totalPaid: totalPaid,
      remaining: remainingFromDb == 0 ? (totalPrice - totalPaid) : remainingFromDb,
      emiDay: _asInt(data['emiDay']) == 0 ? 5 : _asInt(data['emiDay']),
      nextEmiDate: _asDateTime(data['nextEmiDate']),
      aadharUrl: data['aadharUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap({String? aadharUrlOverride}) {
    return {
      'name': name,
      'phone': phone,
      'totalPrice': totalPrice,
      'emiDay': emiDay,
      'totalPaid': totalPaid,
      'remaining': remaining,
      if ((aadharUrlOverride ?? aadharUrl) != null)
        'aadharUrl': (aadharUrlOverride ?? aadharUrl),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
