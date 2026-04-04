import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerAnalyticsScreen extends StatelessWidget {
  const LedgerAnalyticsScreen({super.key});

  Future<Map<String, int>> calculateLedgerStats() async {

    int totalLent = 0;
    int totalBorrowed = 0;
    int interestEarned = 0;
    int interestPaid = 0;

    /// LENDING
    var lending = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('lending')
        .get();

    for (var loan in lending.docs) {

      var loanData = loan.data();

      totalLent += (loanData['principal'] ?? 0) as int;

      var installments = await loan.reference
          .collection('installments')
          .get();

      for (var ins in installments.docs) {

        var pay = ins.data();

        interestEarned += (pay['interestPaid'] ?? 0) as int;

      }
    }

    /// BORROWING
    var borrowing = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .get();

    for (var loan in borrowing.docs) {

      var loanData = loan.data();

      totalBorrowed += (loanData['principal'] ?? 0) as int;

      var installments = await loan.reference
          .collection('installments')
          .get();

      for (var ins in installments.docs) {

        var pay = ins.data();

        interestPaid += (pay['interestPaid'] ?? 0) as int;

      }
    }

    return {
      "lent": totalLent,
      "borrowed": totalBorrowed,
      "earned": interestEarned,
      "paid": interestPaid,
      "profit": interestEarned - interestPaid
    };
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ledger Analytics"),
      ),

      body: FutureBuilder(
        future: calculateLedgerStats(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          var data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [

                _card("Total Lent", data['lent']!),

                const SizedBox(height: 15),

                _card("Total Borrowed", data['borrowed']!),

                const SizedBox(height: 15),

                _card("Interest Earned", data['earned']!),

                const SizedBox(height: 15),

                _card("Interest Paid", data['paid']!),

                const SizedBox(height: 15),

                _card("Net Profit", data['profit']!),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, int amount) {

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              "₹ $amount",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            )

          ],
        ),
      ),
    );
  }
}