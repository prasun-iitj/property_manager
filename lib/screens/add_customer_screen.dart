import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';

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

  String? aadharFileName;
  Uint8List? aadharFileBytes;

  bool isLoading = false; // ✅ NEW

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      loadCustomer();
    }
  }

  Future<void> pickAadharFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        aadharFileName = result.files.single.name;
        aadharFileBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> loadCustomer() async {
    final doc = await FirebaseFirestore.instance
        .collection('sites')
        .doc(widget.siteId)
        .collection('plots')
        .doc(widget.plotId)
        .collection('customer')
        .doc('details')
        .get();

    if (doc.exists) {
      final data = doc.data() ?? {};

      nameController.text = data['name']?.toString() ?? "";
      phoneController.text = data['phone']?.toString() ?? "";
      totalPriceController.text =
          (data['totalPrice'] ?? 0).toString();
      emiDayController.text =
          (data['emiDay'] ?? 5).toString();
    }
  }

  Future<void> saveCustomer() async {
    try {
      setState(() => isLoading = true);

      int totalPrice =
          int.tryParse(totalPriceController.text.trim()) ?? 0;

      int emiDay =
          int.tryParse(emiDayController.text.trim()) ?? 5;

      if (emiDay < 1 || emiDay > 28) {
        emiDay = 5;
      }

      final customerRef = FirebaseFirestore.instance
          .collection('sites')
          .doc(widget.siteId)
          .collection('plots')
          .doc(widget.plotId)
          .collection('customer')
          .doc('details');

      final existingDoc = await customerRef.get();
      final existingData = existingDoc.data() ?? {};

      int totalPaid = existingData['totalPaid'] ?? 0;
      int remaining = totalPrice - totalPaid;

      String? aadharUrl;

      // ✅ SAFE UPLOAD (won't break UI)
      if (aadharFileBytes != null && aadharFileName != null) {
        try {
          final storageService = StorageService();

          aadharUrl = await storageService.uploadAadharWeb(
            fileBytes: aadharFileBytes!,
            customerId: widget.plotId,
            fileName: aadharFileName!,
          );
        } catch (e) {
          print("Upload failed: $e");
        }
      }

      await customerRef.set(
        {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'totalPrice': totalPrice,
          'emiDay': emiDay,
          'totalPaid': totalPaid,
          'remaining': remaining,
          if (aadharUrl != null) 'aadharUrl': aadharUrl,
        },
        SetOptions(merge: true),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("SAVE ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    totalPriceController.dispose();
    emiDayController.dispose();
    super.dispose();
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
              const SizedBox(height: 10),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: "Phone"),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: totalPriceController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Total Price"),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: emiDayController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "EMI Day (1-28)"),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Aadhar Document",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: pickAadharFile,
                child: const Text("Select Aadhar"),
              ),

              const SizedBox(height: 10),

              Text(
                aadharFileName != null
                    ? "Selected: $aadharFileName"
                    : "No file selected",
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveCustomer,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.isEdit ? "Update" : "Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}