import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_installment_screen.dart';
import '../../services/pdf_service.dart';
import '../../widgets/breadcrumb.dart';

class BorrowingDetailScreen extends StatelessWidget {
  final String borrowId;

  const BorrowingDetailScreen({
    super.key,
    required this.borrowId,
  });

  Future<void> exportPdf(BuildContext context) async {
    var borrowRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .doc(borrowId);

    var borrowDoc = await borrowRef.get();
    var borrowData = borrowDoc.data() as Map<String, dynamic>;

    var installmentsSnap =
        await borrowRef.collection('installments').orderBy('date').get();

    List installments = installmentsSnap.docs.map((doc) {
      var pay = doc.data();
      Timestamp ts = pay['date'];
      DateTime d = ts.toDate();

      return {
        "date": "${d.day}/${d.month}/${d.year}",
        "amount": pay['amount'],
        "principalPaid": pay['principalPaid'],
        "interestPaid": pay['interestPaid'],
      };
    }).toList();

    await PdfService.generateLedgerPdf(
      borrowData['name'],
      borrowData['principal'].toDouble(),
      borrowData['interestRate'].toDouble(),
      installments,
    );
  }

  // 🔥 RECALCULATION
  Future<void> _recalculate(DocumentReference ref) async {
    var snap = await ref.collection('installments').get();

    double totalPrincipalPaid = 0;

    for (var doc in snap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      totalPrincipalPaid +=
          (data['principalPaid'] ?? 0).toDouble();
    }

    var mainDoc = await ref.get();
    var mainData = mainDoc.data() as Map<String, dynamic>;

    double principal =
        (mainData['principal'] ?? 0).toDouble();

    double newRemaining = principal - totalPrincipalPaid;
    if (newRemaining < 0) newRemaining = 0;

    await ref.update({
      'remainingPrincipal': newRemaining,
    });
  }

  // 🔥 DELETE + UNDO
  Future<void> deleteInstallment(
      BuildContext context, String installmentId) async {

    final ref = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .doc(borrowId);

    final installmentRef =
        ref.collection('installments').doc(installmentId);

    var snapshot = await installmentRef.get();
    if (!snapshot.exists) return;

    var deletedData = snapshot.data();

    await installmentRef.delete();
    await _recalculate(ref);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Installment deleted"),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "UNDO",
          onPressed: () async {
            await installmentRef.set(deletedData!);
            await _recalculate(ref);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Restored")),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    var borrowRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .doc(borrowId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Borrowing Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => exportPdf(context),
          ),
        ],
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
                  onTap: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                ),
                BreadcrumbItem(
                  label: "Borrowing",
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(label: "Details"),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: borrowRef.snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var data =
                    snapshot.data!.data() as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      // Summary
                      Card(
                        child: ListTile(
                          title: Text(data['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Principal ₹ ${data['principal']}"),
                              Text("Interest ${data['interestRate']}%"),
                              Text(
                                "Remaining ₹ ${data['remainingPrincipal']}",
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Installments",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: borrowRef
                              .collection('installments')
                              .orderBy('date', descending: true)
                              .snapshots(),
                          builder: (context, snap) {

                            if (!snap.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            var docs = snap.data!.docs;

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {

                                var doc = docs[index];
                                var pay =
                                    doc.data() as Map<String, dynamic>;

                                Timestamp ts = pay['date'];
                                DateTime d = ts.toDate();

                                return ListTile(
                                  title: Text("₹ ${pay['amount']}"),
                                  subtitle: Text(
                                      "${d.day}/${d.month}/${d.year}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => deleteInstallment(
                                        context, doc.id),
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
              },
            ),
          ),
        ],
      ),

      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: borrowRef.snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) return const SizedBox();

          var data =
              snapshot.data!.data() as Map<String, dynamic>;

          return FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text("Add Installment"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddInstallmentScreen(
                    loanId: borrowId,
                    principal: data['remainingPrincipal'],
                    interestRate: data['interestRate'],
                    ledgerType: "borrowing",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}