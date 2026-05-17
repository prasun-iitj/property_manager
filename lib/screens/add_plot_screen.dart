import 'package:flutter/material.dart';
import '../models/plot_model.dart';
import '../services/plot_service.dart';

class AddPlotScreen extends StatefulWidget {
  final String siteId;

  const AddPlotScreen({super.key, required this.siteId});

  @override
  State<AddPlotScreen> createState() => _AddPlotScreenState();
}

class _AddPlotScreenState extends State<AddPlotScreen> {
  final PlotService _plotService = PlotService();
  final plotController = TextEditingController();
  final priceController = TextEditingController();
  bool isSaving = false;

  @override
  void dispose() {
    plotController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> addPlot() async {
    final plotNumber = plotController.text.trim();
    final totalPrice = int.tryParse(priceController.text.trim());

    if (plotNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter plot number")),
      );
      return;
    }

    if (totalPrice == null || totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid total price")),
      );
      return;
    }

    setState(() => isSaving = true);

    final plot = PlotModel(
      id: '',
      plotNumber: plotNumber,
      totalPrice: totalPrice,
      status: 'available',
    );

    try {
      final taken = await _plotService.isPlotNumberTaken(
        siteId: widget.siteId,
        plotNumber: plotNumber,
      );
      if (taken) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plot "$plotNumber" already exists in this site. '
              'Choose a different number.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      await _plotService.addPlot(siteId: widget.siteId, plot: plot);
      if (!mounted) return;
      Navigator.pop(context);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save plot. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
              decoration: const InputDecoration(
                labelText: "Plot Number",
                hintText: "Must be unique within this site",
                helperText: "Each plot needs a different number (e.g. 1, 2, 3)",
              ),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Price"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSaving ? null : addPlot,
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save Plot"),
            )
          ],
        ),
      ),
    );
  }
}