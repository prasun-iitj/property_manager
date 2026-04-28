import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AddPaymentScreen extends StatefulWidget {
  final String siteId;
  final String plotId;

  const AddPaymentScreen({
    super.key,
    required this.siteId,
    required this.plotId,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final TextEditingController amountController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedMode = "Cash";

  bool isLoading = false;

  Future<void> addPayment() async {
    try {
      if (amountController.text.trim().isEmpty) {
        showError("Please enter amount");
        return;
      }

      int? amount = int.tryParse(amountController.text.trim());
      if (amount == null || amount <= 0) {
        showError("Invalid amount");
        return;
      }

      setState(() => isLoading = true);

      final customerRef = FirebaseFirestore.instance
          .collection('sites')
          .doc(widget.siteId)
          .collection('plots')
          .doc(widget.plotId)
          .collection('customer')
          .doc('details');

      final customerDoc = await customerRef.get();

      if (!customerDoc.exists) {
        showError("Customer not found");
        return;
      }

      final data = customerDoc.data() ?? {};

      // ✅ SAFE TYPE HANDLING
      int totalPaid = 0;
      int totalPrice = 0;
      int emiDay = 5;

      if (data['totalPaid'] != null) {
        if (data['totalPaid'] is int) {
          totalPaid = data['totalPaid'];
        } else {
          totalPaid = int.tryParse(data['totalPaid'].toString()) ?? 0;
        }
      }

      if (data['totalPrice'] != null) {
        if (data['totalPrice'] is int) {
          totalPrice = data['totalPrice'];
        } else {
          totalPrice = int.tryParse(data['totalPrice'].toString()) ?? 0;
        }
      }

      if (data['emiDay'] != null) {
        if (data['emiDay'] is int) {
          emiDay = data['emiDay'];
        } else {
          emiDay = int.tryParse(data['emiDay'].toString()) ?? 5;
        }
      }

      final int newTotalPaid = totalPaid + amount;
      final int remaining = totalPrice - newTotalPaid;

      // ✅ SAVE PAYMENT
      await customerRef.collection('payments').add({
        'amount': amount,
        'date': Timestamp.fromDate(selectedDate),
        'mode': selectedMode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ EMI CALCULATION
      DateTime nextEmi;
      if (selectedDate.day >= emiDay) {
        nextEmi = DateTime(selectedDate.year, selectedDate.month + 1, emiDay);
      } else {
        nextEmi = DateTime(selectedDate.year, selectedDate.month, emiDay);
      }

      // ✅ UPDATE CUSTOMER
      await customerRef.update({
        'totalPaid': newTotalPaid,
        'remaining': remaining,
        'nextEmiDate': Timestamp.fromDate(nextEmi),
      });

      // ✅ WHATSAPP (SAFE)
      final String phone = data['phone']?.toString() ?? "";

      if (phone.isNotEmpty) {
        await sendWhatsAppMessage(phone, amount, newTotalPaid, remaining);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      showError("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendWhatsAppMessage(
    String phone,
    int amount,
    int totalPaid,
    int remaining,
  ) async {
    try {
      final message = '''
Payment Received Successfully

Amount Paid: ₹$amount
Total Paid: ₹$totalPaid
Remaining Amount: ₹$remaining

Thank you.
''';

      final url =
          "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}";

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Payment")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Payment Amount",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ListTile(
              title: Text(
                "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: selectedMode,
              decoration: const InputDecoration(
                labelText: "Payment Mode",
                border: OutlineInputBorder(),
              ),
              items: ["Cash", "UPI", "Bank"]
                  .map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedMode = value);
                }
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: addPayment,
                      child: const Text("Save Payment"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}