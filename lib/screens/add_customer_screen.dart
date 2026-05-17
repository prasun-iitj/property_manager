import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';

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
  final CustomerService _customerService = CustomerService();
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
    FilePickerResult? result = await FilePicker.pickFiles(
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
    final doc = await _customerService.getCustomerDetails(
      siteId: widget.siteId,
      plotId: widget.plotId,
    );

    if (doc.exists) {
      final data = doc.data() ?? {};
      final customer = CustomerModel.fromMap(data);

      nameController.text = customer.name;
      phoneController.text = customer.phone;
      totalPriceController.text = customer.totalPrice.toString();
      emiDayController.text = customer.emiDay.toString();
    }
  }

  Future<void> saveCustomer() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final totalPrice = int.tryParse(totalPriceController.text.trim()) ?? 0;
    int emiDay = int.tryParse(emiDayController.text.trim()) ?? 5;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Customer name is required")),
      );
      return;
    }

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid phone number")),
      );
      return;
    }

    if (totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Total price must be greater than zero")),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      if (emiDay < 1 || emiDay > 28) {
        emiDay = 5;
      }

      final existingDoc = await _customerService.getCustomerDetails(
        siteId: widget.siteId,
        plotId: widget.plotId,
      );
      final existingData = existingDoc.data() ?? {};

      int totalPaid = existingData['totalPaid'] ?? 0;
      int remaining = totalPrice - totalPaid;
      if (remaining < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Total price cannot be less than already paid amount"),
          ),
        );
        return;
      }

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
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aadhaar upload failed. Details will be saved without file."),
            ),
          );
        }
      }

      final customer = CustomerModel(
        name: name,
        phone: phone,
        totalPrice: totalPrice,
        emiDay: emiDay,
        totalPaid: totalPaid,
        remaining: remaining,
        aadharUrl: existingData['aadharUrl']?.toString(),
      );

      await _customerService.saveCustomer(
        siteId: widget.siteId,
        plotId: widget.plotId,
        customer: CustomerModel(
          name: customer.name,
          phone: customer.phone,
          totalPrice: customer.totalPrice,
          totalPaid: customer.totalPaid,
          remaining: customer.remaining,
          emiDay: customer.emiDay,
          nextEmiDate: customer.nextEmiDate,
          aadharUrl: aadharUrl ?? customer.aadharUrl,
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save customer details")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                      : Text(widget.isEdit ? "Update Customer" : "Save Customer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}