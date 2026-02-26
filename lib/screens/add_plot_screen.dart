import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPlotScreen extends StatefulWidget {
  final String siteId;

  const AddPlotScreen({super.key, required this.siteId});

  @override
  State<AddPlotScreen> createState() => _AddPlotScreenState();
}

class _AddPlotScreenState extends State<AddPlotScreen> {
  final plotController = TextEditingController();
  final priceController = TextEditingController();

  Future<void> addPlot() async {
    await FirebaseFirestore.instance
        .collection('sites')
        .doc(widget.siteId)
        .collection('plots')
        .add({
      'plotNumber': plotController.text.trim(),
      'totalPrice': int.parse(priceController.text.trim()),
      'status': 'available'
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Plot")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: plotController,
              decoration: const InputDecoration(labelText: "Plot Number"),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Price"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: addPlot,
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}