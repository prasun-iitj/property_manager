import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'borrowing_detail_screen.dart';
import 'add_borrowing_screen.dart';
import '../../services/app_cache.dart';
import '../../widgets/breadcrumb.dart';
import '../../utils/ledger_calculator.dart';

class BorrowingListScreen extends StatelessWidget {
  const BorrowingListScreen({super.key});

  // 🔥 DELETE BORROWING (CASCADE)
  Future<void> deleteBorrowing(BuildContext context, String borrowId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Borrowing"),
        content: const Text("This will delete all installments. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ref = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .doc(borrowId);

    try {
      // 🔥 delete installments first
      var snap = await ref.collection('installments').get();

      for (var doc in snap.docs) {
        await doc.reference.delete();
      }

      // 🔥 delete main doc
      await ref.delete();
      AppCache.instance.invalidateLedger();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Borrowing deleted")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error deleting")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var borrowingRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Borrowing"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Borrowing"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddBorrowingScreen(),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ UPDATED BREADCRUMB
          Padding(
            padding: const EdgeInsets.all(10),
            child: Breadcrumb(
              items: [
                BreadcrumbItem(
                  label: "Home",
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(
                  label: "Borrowing",
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: borrowingRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No Borrowing Records"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    final remaining = _asInt(data['remainingPrincipal']);
                    final isOverpaid = remaining < 0;

                    return Card(
                      color: isOverpaid ? Colors.orange.shade50 : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: isOverpaid
                              ? Colors.deepOrange
                              : const Color(0xFF1E3A8A),
                          child: Icon(
                            isOverpaid ? Icons.warning_amber : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(data['name'] ?? ""),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Principal ${LedgerMoneyFormat.rupees(_asInt(data['principal']))}",
                            ),
                            Text(
                              isOverpaid
                                  ? "Overpaid ${LedgerMoneyFormat.rupees(-remaining)}"
                                  : "Balance ${LedgerMoneyFormat.rupees(remaining)}",
                              style: TextStyle(
                                color: isOverpaid ? Colors.deepOrange : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ➡️ open details
                            IconButton(
                              icon:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BorrowingDetailScreen(
                                      borrowId: doc.id,
                                    ),
                                  ),
                                );
                              },
                            ),

                            // ❌ delete
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteBorrowing(context, doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
