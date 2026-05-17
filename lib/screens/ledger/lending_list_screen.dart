import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lending_detail_screen.dart';
import 'add_lending_screen.dart';
import '../../widgets/breadcrumb.dart';
import '../../utils/ledger_calculator.dart';

class LendingListScreen extends StatelessWidget {
  const LendingListScreen({super.key});

  // 🔥 DELETE LOAN (CASCADE)
  Future<void> deleteLoan(BuildContext context, String loanId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Loan"),
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
        .collection('lending')
        .doc(loanId);

    try {
      var snap = await ref.collection('installments').get();

      for (var doc in snap.docs) {
        await doc.reference.delete();
      }

      await ref.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loan deleted")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error deleting loan")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var lendingRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('lending');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lending"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Loan"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddLendingScreen(),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Breadcrumb
          Padding(
            padding: const EdgeInsets.all(10),
            child: Breadcrumb(
              items: [
                BreadcrumbItem(
                  label: "Home",
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(label: "Lending"),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: lendingRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No Lending Records"),
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
                        title: Text(
                          data['name'] ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                            // ➡️ DETAILS
                            IconButton(
                              icon:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LendingDetailScreen(
                                      loanId: doc.id,
                                    ),
                                  ),
                                );
                              },
                            ),

                            // ❌ DELETE
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteLoan(context, doc.id),
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
