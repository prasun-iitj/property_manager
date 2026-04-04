import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddBorrowingScreen extends StatefulWidget {
  const AddBorrowingScreen({super.key});

  @override
  State<AddBorrowingScreen> createState() => _AddBorrowingScreenState();
}

class _AddBorrowingScreenState extends State<AddBorrowingScreen> {

  final nameController = TextEditingController();
  final principalController = TextEditingController();
  final interestController = TextEditingController();
  final emiController = TextEditingController();
  final durationController = TextEditingController();

  bool loading = false;

  void calculateEmi() {

    if (principalController.text.isEmpty ||
        interestController.text.isEmpty ||
        durationController.text.isEmpty) return;

    int principal = int.tryParse(principalController.text) ?? 0;
    int rate = int.tryParse(interestController.text) ?? 0;
    int months = int.tryParse(durationController.text) ?? 0;

    if (months == 0) return;

    int emi = ((principal + (principal * rate / 100 * months)) / months).round();

    emiController.text = emi.toString();
  }

  Future<void> saveBorrowing() async {

    if (nameController.text.trim().isEmpty ||
        principalController.text.isEmpty ||
        interestController.text.isEmpty ||
        emiController.text.isEmpty ||
        durationController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );

      return;
    }

    setState(() => loading = true);

    try {

      int principal = int.parse(principalController.text);
      int rate = int.parse(interestController.text);
      int emi = int.parse(emiController.text);
      int months = int.parse(durationController.text);

      await FirebaseFirestore.instance
          .collection('ledger')
          .doc('data')
          .collection('borrowing')
          .add({

        "name": nameController.text.trim(),
        "principal": principal,
        "remainingPrincipal": principal,
        "interestRate": rate,
        "emiAmount": emi,
        "durationMonths": months,
        "startDate": Timestamp.now(),
        "createdAt": Timestamp.now(),
        "status": "active",
        "totalPaid": 0

      });

      if (mounted) Navigator.pop(context);

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save borrowing")),
      );

    } finally {

      if (mounted) {
        setState(() => loading = false);
      }

    }
  }

  Widget buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    Function(String)? onChanged,
  }) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 16),

      child: TextField(

        controller: controller,
        keyboardType: type,
        onChanged: onChanged,

        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),

      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Add Borrowing"),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Borrowing Details",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            buildField(
              nameController,
              "Person Name",
              Icons.person,
            ),

            buildField(
              principalController,
              "Principal Amount",
              Icons.currency_rupee,
              type: TextInputType.number,
              onChanged: (_) => calculateEmi(),
            ),

            buildField(
              interestController,
              "Interest % per month",
              Icons.percent,
              type: TextInputType.number,
              onChanged: (_) => calculateEmi(),
            ),

            buildField(
              durationController,
              "Duration (Months)",
              Icons.calendar_month,
              type: TextInputType.number,
              onChanged: (_) => calculateEmi(),
            ),

            buildField(
              emiController,
              "EMI Amount",
              Icons.payments,
              type: TextInputType.number,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(

                onPressed: loading ? null : saveBorrowing,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Borrowing",
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