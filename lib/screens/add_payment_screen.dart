import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/customer_service.dart';
import '../utils/ledger_calculator.dart';

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
  final CustomerService _customerService = CustomerService();
  final TextEditingController amountController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedMode = "Cash";

  bool isLoading = false;
  int _totalPrice = 0;
  int _totalPaid = 0;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    amountController.addListener(() => setState(() {}));
  }

  Future<void> _loadBalance() async {
    try {
      final doc = await _customerService.getCustomerDetails(
        siteId: widget.siteId,
        plotId: widget.plotId,
      );
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      final totalPrice = _asInt(data['totalPrice']);
      final totalPaid = _asInt(data['totalPaid']);
      final remainingFromDb = _asInt(data['remaining']);
      setState(() {
        _totalPrice = totalPrice;
        _totalPaid = totalPaid;
        _remaining = remainingFromDb == 0 && totalPrice > 0
            ? totalPrice - totalPaid
            : remainingFromDb;
      });
    } catch (_) {
      // Balance hint is optional.
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? get _enteredAmount => int.tryParse(amountController.text.trim());

  int get _balanceAfterPayment {
    final amount = _enteredAmount ?? 0;
    return _remaining - amount;
  }

  Future<void> addPayment() async {
    try {
      if (amountController.text.trim().isEmpty) {
        showError("Please enter payment amount");
        return;
      }

      final amount = _enteredAmount;
      if (amount == null || amount <= 0) {
        showError("Please enter a valid amount");
        return;
      }

      setState(() => isLoading = true);

      final result = await _customerService.addPayment(
        siteId: widget.siteId,
        plotId: widget.plotId,
        amount: amount,
        selectedDate: selectedDate,
        mode: selectedMode,
      );

      if (result.phone.isNotEmpty) {
        await sendWhatsAppMessage(
          result.phone,
          amount,
          result.totalPaid,
          result.remaining,
        );
      }

      if (mounted) Navigator.pop(context);
    } on StateError catch (e) {
      showError(e.message);
    } catch (_) {
      showError("Could not save payment. Please try again.");
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
      final balanceLine = remaining < 0
          ? 'Overpaid: ${LedgerMoneyFormat.rupees(-remaining)} (credit)'
          : 'Remaining Amount: ${LedgerMoneyFormat.rupees(remaining)}';

      final message = '''
Payment Received Successfully

Amount Paid: ₹$amount
Total Paid: ₹$totalPaid
$balanceLine

Thank you.
''';

      final url = "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}";
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
    final entered = _enteredAmount;
    final willOverpay = entered != null && entered > 0 && _balanceAfterPayment < 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Add Payment")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFFEFF6FF),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plot balance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total price', style: TextStyle(color: Colors.grey.shade700)),
                        Text(LedgerMoneyFormat.rupees(_totalPrice)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Paid so far', style: TextStyle(color: Colors.grey.shade700)),
                        Text(LedgerMoneyFormat.rupees(_totalPaid)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _remaining < 0 ? 'Overpaid' : 'Balance due',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _remaining < 0
                              ? LedgerMoneyFormat.rupees(-_remaining)
                              : LedgerMoneyFormat.rupees(_remaining),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _remaining < 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Payment Amount",
                hintText: "Enter amount (overpayment allowed)",
                border: OutlineInputBorder(),
              ),
            ),
            if (entered != null && entered > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: willOverpay
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: willOverpay ? Colors.amber.shade700 : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  willOverpay
                      ? 'After this payment: overpaid '
                          '${LedgerMoneyFormat.rupees(-_balanceAfterPayment)} '
                          '(balance will be negative)'
                      : 'After this payment: '
                          '${LedgerMoneyFormat.rupees(_balanceAfterPayment)} remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: willOverpay ? Colors.amber.shade900 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ListTile(
              title: Text(
                "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
              ),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: () async {
                final picked = await showDatePicker(
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: addPayment,
                      child: const Text("Save Payment Entry"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
