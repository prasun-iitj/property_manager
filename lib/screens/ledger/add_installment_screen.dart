import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddInstallmentScreen extends StatefulWidget {
  final String loanId;
  final int principal;
  final int interestRate;
  final String ledgerType;

  const AddInstallmentScreen({
    super.key,
    required this.loanId,
    required this.principal,
    required this.interestRate,
    required this.ledgerType,
  });

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  DateTime paymentDate = DateTime.now();

  bool loading = false;

  Future<void> saveInstallment() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter installment amount")));

      return;
    }

    int amount = int.parse(amountController.text);

    double interest = (widget.principal * widget.interestRate) / 100;

    int interestDue = interest.round();

    int interestPaid = 0;
    int principalPaid = 0;

    if (amount >= interestDue) {
      interestPaid = interestDue;
      principalPaid = amount - interestDue;
    } else {
      interestPaid = amount;
      principalPaid = 0;
    }

    int newPrincipal = widget.principal - principalPaid;

    if (newPrincipal < 0) newPrincipal = 0;

    setState(() {
      loading = true;
    });

    var loanRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection(widget.ledgerType)
        .doc(widget.loanId);

    await loanRef.collection('installments').add({
      "amount": amount,
      "interestPaid": interestPaid,
      "principalPaid": principalPaid,

      "date": Timestamp.fromDate(paymentDate),

      "nextDueDate": Timestamp.fromDate(
        paymentDate.add(const Duration(days: 30)),
      ),

      "note": noteController.text.trim(),
    });

    await loanRef.update({
      "remainingPrincipal": newPrincipal,
      "totalPaid": FieldValue.increment(amount),
    });

    setState(() {
      loading = false;
    });

    Navigator.pop(context);
  }

  Widget buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: TextField(
        controller: controller,
        keyboardType: type,

        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Installment")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Installment Payment",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            buildField(
              amountController,
              "Installment Amount",
              Icons.currency_rupee,
              type: TextInputType.number,
            ),

            buildField(noteController, "Note (Optional)", Icons.note),

            const SizedBox(height: 10),

            ListTile(
              leading: const Icon(Icons.calendar_today),

              title: Text(
                "Payment Date: ${paymentDate.day}/${paymentDate.month}/${paymentDate.year}",
              ),

              trailing: const Icon(Icons.edit),

              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  setState(() {
                    paymentDate = picked;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(
                onPressed: loading ? null : saveInstallment,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Installment",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
