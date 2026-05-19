import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_cache.dart';

class AddLendingScreen extends StatefulWidget {
  const AddLendingScreen({super.key});

  @override
  State<AddLendingScreen> createState() => _AddLendingScreenState();
}

class _AddLendingScreenState extends State<AddLendingScreen> {
  final nameController = TextEditingController();
  final principalController = TextEditingController();
  final interestController = TextEditingController();
  final emiController = TextEditingController();
  final durationController = TextEditingController();

  bool loading = false;

  void calculateEmi() {
    if (principalController.text.isEmpty ||
        interestController.text.isEmpty ||
        durationController.text.isEmpty) {
      return;
    }

    int principal = int.tryParse(principalController.text) ?? 0;
    int rate = int.tryParse(interestController.text) ?? 0;
    int months = int.tryParse(durationController.text) ?? 0;

    if (months == 0) return;

    int emi =
        ((principal + (principal * rate / 100 * months)) / months).round();

    emiController.text = emi.toString();
  }

  Future<void> saveLoan() async {
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
      final principal = int.tryParse(principalController.text.trim());
      final rate = int.tryParse(interestController.text.trim());
      final emi = int.tryParse(emiController.text.trim());
      final months = int.tryParse(durationController.text.trim());

      if (principal == null ||
          rate == null ||
          emi == null ||
          months == null ||
          principal <= 0 ||
          rate < 0 ||
          emi <= 0 ||
          months <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Enter valid positive numeric values"),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('ledger')
          .doc('data')
          .collection('lending')
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
      AppCache.instance.invalidateLedger();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save loan")),
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
  void dispose() {
    nameController.dispose();
    principalController.dispose();
    interestController.dispose();
    emiController.dispose();
    durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Lending"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Loan Details",
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
                onPressed: loading ? null : saveLoan,
                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        "Save Loan",
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
