import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

class CustomerSearchResult {
  final String siteId;
  final String plotId;
  final String plotNumber;
  final String name;
  final String phone;
  final int remaining;
  final int totalPrice;
  final int totalPaid;

  const CustomerSearchResult({
    required this.siteId,
    required this.plotId,
    required this.plotNumber,
    required this.name,
    required this.phone,
    required this.remaining,
    this.totalPrice = 0,
    this.totalPaid = 0,
  });
}

class SearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<CustomerSearchResult>> searchCustomersInSite({
    required String siteId,
    required String query,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final plotsSnap =
        await _db.collection(FirestorePaths.sites).doc(siteId).collection(FirestorePaths.plots).get();

    final results = <CustomerSearchResult>[];

    for (final plot in plotsSnap.docs) {
      final customerSnap = await plot.reference
          .collection(FirestorePaths.customer)
          .doc(FirestorePaths.customerDetailsId)
          .get();

      if (!customerSnap.exists) continue;

      final data = customerSnap.data() ?? {};
      final name = (data['name'] ?? '').toString();
      final phone = (data['phone'] ?? '').toString();

      if (!name.toLowerCase().contains(q) && !phone.toLowerCase().contains(q)) {
        continue;
      }

      final totalPrice = _asInt(data['totalPrice']);
      final totalPaid = _asInt(data['totalPaid']);
      results.add(
        CustomerSearchResult(
          siteId: siteId,
          plotId: plot.id,
          plotNumber: (plot.data()['plotNumber'] ?? plot.id).toString(),
          name: name,
          phone: phone,
          remaining: _asInt(data['remaining']),
          totalPrice: totalPrice,
          totalPaid: totalPaid,
        ),
      );
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
