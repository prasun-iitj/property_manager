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
  final amountController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedMode = "Cash"; // ✅ MOVED HERE (Correct place)

  Future<void> addPayment() async {
    if (amountController.text.trim().isEmpty) return;

    int amount = int.parse(amountController.text.trim());

    var customerRef = FirebaseFirestore.instance
        .collection('sites')
        .doc(widget.siteId)
        .collection('plots')
        .doc(widget.plotId)
        .collection('customer')
        .doc('details');

    var customerDoc = await customerRef.get();

    if (!customerDoc.exists) return;

    int totalPaid = customerDoc['totalPaid'] ?? 0;
    int totalPrice = customerDoc['totalPrice'] ?? 0;

    int newTotalPaid = totalPaid + amount;
    int remaining = totalPrice - newTotalPaid;

    // Add payment record
    await customerRef.collection('payments').add({
      'amount': amount,
      'date': Timestamp.fromDate(selectedDate),
      'mode': selectedMode,
    });

    int emiDay =
        customerDoc.data() != null &&
            (customerDoc.data() as Map).containsKey('emiDay')
        ? customerDoc['emiDay']
        : 5;

    DateTime now = selectedDate;
    DateTime nextEmi;

    if (now.day >= emiDay) {
      nextEmi = DateTime(now.year, now.month + 1, emiDay);
    } else {
      nextEmi = DateTime(now.year, now.month, emiDay);
    }

    // Update totals
    await customerRef.update({
      'totalPaid': newTotalPaid,
      'remaining': remaining,
      'nextEmiDate': Timestamp.fromDate(nextEmi),
    });

    String phone = customerDoc['phone'];

    await sendWhatsAppMessage(phone, amount, newTotalPaid, remaining);

    Navigator.pop(context);
  }

  Future<void> sendWhatsAppMessage(
    String phone,
    int amount,
    int totalPaid,
    int remaining,
  ) async {
    String message =
        """
Payment Received Successfully

Amount Paid: ₹$amount
Total Paid: ₹$totalPaid
Remaining Amount: ₹$remaining

Thank you.
""";

    String url = "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}";

    final Uri whatsappUri = Uri.parse(url);

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
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
              decoration: const InputDecoration(labelText: "Payment Amount"),
            ),
            const SizedBox(height: 20),

            // Date Picker
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
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
            ),

            const SizedBox(height: 10),

            // Payment Mode Dropdown
            DropdownButtonFormField<String>(
              initialValue: selectedMode,
              decoration: const InputDecoration(labelText: "Payment Mode"),
              items: ["Cash", "UPI", "Bank"]
                  .map(
                    (mode) => DropdownMenuItem(value: mode, child: Text(mode)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMode = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: addPayment,
              child: const Text("Save Payment"),
            ),
          ],
        ),
      ),
    );
  }
}
