import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCustomerScreen extends StatefulWidget {
  final String siteId;
  final String plotId;
  final bool isEdit;

  const AddCustomerScreen({
    super.key,
    required this.siteId,
    required this.plotId,
    this.isEdit = false,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final totalPriceController = TextEditingController();
  final emiDayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      loadCustomer();
    }
  }

  Future<void> loadCustomer() async {
    var doc = await FirebaseFirestore.instance
        .collection('sites')
        .doc(widget.siteId)
        .collection('plots')
        .doc(widget.plotId)
        .collection('customer')
        .doc('details')
        .get();

    if (doc.exists) {
      var data = doc.data()!;
      nameController.text = data['name'] ?? "";
      phoneController.text = data['phone'] ?? "";
      totalPriceController.text =
          (data['totalPrice'] ?? 0).toString();
      emiDayController.text =
          (data['emiDay'] ?? "").toString();
    }
  }

  Future<void> saveCustomer() async {
    int totalPrice =
        int.tryParse(totalPriceController.text.trim()) ?? 0;
    int emiDay =
        int.tryParse(emiDayController.text.trim()) ?? 1;

    await FirebaseFirestore.instance
        .collection('sites')
        .doc(widget.siteId)
        .collection('plots')
        .doc(widget.plotId)
        .collection('customer')
        .doc('details')
        .set(
      {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'totalPrice': totalPrice,
        'emiDay': emiDay,

        // Only set these when creating new customer
        if (!widget.isEdit) ...{
          'totalPaid': 0,
          'remaining': totalPrice,
        }
      },
      SetOptions(merge: true),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit
            ? "Edit Customer"
            : "Assign Customer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: "Customer Name"),
              ),
              TextField(
                controller: phoneController,
                decoration:
                    const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: totalPriceController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Total Price"),
              ),
              TextField(
                controller: emiDayController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "EMI Day (1-28)"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saveCustomer,
                child: Text(widget.isEdit ? "Update" : "Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}