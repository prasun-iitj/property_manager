import 'package:cloud_firestore/cloud_firestore.dart';

class PlotModel {
  final String id;
  final String plotNumber;
  final int totalPrice;
  final String status;
  final DateTime? createdAt;

  const PlotModel({
    required this.id,
    required this.plotNumber,
    required this.totalPrice,
    required this.status,
    this.createdAt,
  });

  factory PlotModel.fromMap(String id, Map<String, dynamic> data) {
    return PlotModel(
      id: id,
      plotNumber: (data['plotNumber'] ?? '').toString(),
      totalPrice: _asInt(data['totalPrice']),
      status: (data['status'] ?? 'available').toString(),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plotNumber': plotNumber,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
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
