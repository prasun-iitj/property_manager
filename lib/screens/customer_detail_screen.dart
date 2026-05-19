import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_customer_screen.dart';
import 'add_payment_screen.dart';
import 'document_upload_screen.dart';
import '../widgets/stat_card.dart';
import '../widgets/property_chart.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import '../services/property_analytics_service.dart';
import '../utils/whatsapp_launcher.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String siteId;
  final String plotId;
  final String plotNumber;
  final String role;

  const CustomerDetailScreen({
    super.key,
    required this.siteId,
    required this.plotId,
    required this.plotNumber,
    required this.role,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final CustomerService _customerService = CustomerService();
  final PropertyAnalyticsService _analytics = PropertyAnalyticsService();

  Map<int, PropertyMonthBucket> _paymentMonths = {};
  int _chartYear = DateTime.now().year;
  int? _selectedPayMonth;
  String get customerId => "${widget.siteId}_${widget.plotId}";

  @override
  void initState() {
    super.initState();
    _loadPaymentChart();
  }

  Future<void> _loadPaymentChart() async {
    final data = await _analytics.loadPlotPaymentMonthly(
      siteId: widget.siteId,
      plotId: widget.plotId,
      year: _chartYear,
    );
    if (mounted) setState(() => _paymentMonths = data);
  }

  Future<void> deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text(
          'This will remove the customer and all payment records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _customerService.deleteCustomer(
        siteId: widget.siteId,
        plotId: widget.plotId,
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> deletePayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Remove this payment from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _customerService.deletePayment(
        siteId: widget.siteId,
        plotId: widget.plotId,
        paymentId: paymentId,
      );
      if (!mounted) return;
      _loadPaymentChart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted')),
      );
    }
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Plot ${widget.plotNumber}'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        actions: [
          if (widget.role == 'admin')
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit customer',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCustomerScreen(
                      siteId: widget.siteId,
                      plotId: widget.plotId,
                      isEdit: true,
                    ),
                  ),
                );
                setState(() {});
              },
            ),
          if (widget.role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete customer',
              onPressed: deleteCustomer,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentScreen(
                siteId: widget.siteId,
                plotId: widget.plotId,
              ),
            ),
          );
          _loadPaymentChart();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _customerService.streamCustomerDetails(
                siteId: widget.siteId,
                plotId: widget.plotId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No customer assigned to this plot'),
                        if (widget.role == 'admin') ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddCustomerScreen(
                                    siteId: widget.siteId,
                                    plotId: widget.plotId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Customer'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final customer =
                    CustomerModel.fromMap(snapshot.data!.data() ?? {});

                final totalPrice = customer.totalPrice;
                final totalPaid = customer.totalPaid;
                final remaining = customer.remaining;
                DateTime? nextEmi;
                var emiDue = false;
                if (customer.nextEmiDate != null) {
                  nextEmi = customer.nextEmiDate;
                  emiDue = DateTime.now().isAfter(customer.nextEmiDate!);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFF1E3A8A),
                                child: Text(
                                  customer.name.isNotEmpty
                                      ? customer.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name.isEmpty
                                          ? 'Unnamed customer'
                                          : customer.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      customer.phone.isEmpty
                                          ? 'No phone'
                                          : customer.phone,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (customer.phone.isNotEmpty) ...[
                                IconButton(
                                  onPressed: () => launchPaymentWhatsApp(
                                    phone: customer.phone,
                                    message:
                                        'Hello ${customer.name},\n\n$kPaymentWhatsAppSignature',
                                  ),
                                  icon: const Icon(
                                    Icons.message,
                                    color: Color(0xFF25D366),
                                  ),
                                  tooltip: 'WhatsApp customer',
                                ),
                                IconButton(
                                  onPressed: () => _callCustomer(customer.phone),
                                  icon: const Icon(Icons.phone, color: Colors.green),
                                  tooltip: 'Call customer',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentUploadScreen(
                                      siteId: widget.siteId,
                                      plotId: widget.plotId,
                                      customerId: customerId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Documents'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ProgressSummaryCard(
                        title: 'Plot payment progress',
                        total: totalPrice,
                        paid: totalPaid,
                        remaining: remaining,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: PropertyCollectionsChart(
                          buckets: _paymentMonths,
                          year: _chartYear,
                          selectedMonth: _selectedPayMonth,
                          barColor: const Color(0xFF2563EB),
                          onYearChanged: (y) {
                            setState(() {
                              _chartYear = y;
                              _selectedPayMonth = null;
                              _paymentMonths = {};
                            });
                            _loadPaymentChart();
                          },
                          onMonthSelected: (m) =>
                              setState(() => _selectedPayMonth = m),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          StatCard(
                            label: 'EMI day',
                            value: '${customer.emiDay}',
                            icon: Icons.event,
                          ),
                          const SizedBox(width: 10),
                          StatCard(
                            label: 'Next EMI',
                            value: nextEmi != null
                                ? '${nextEmi.day}/${nextEmi.month}/${nextEmi.year}'
                                : '—',
                            icon: Icons.notifications_active,
                            accentColor: emiDue ? Colors.red : null,
                          ),
                        ],
                      ),
                      if (emiDue && nextEmi != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'EMI was due on ${nextEmi.day}/${nextEmi.month}/${nextEmi.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Payment history',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder(
                        stream: _customerService.streamPayments(
                          siteId: widget.siteId,
                          plotId: widget.plotId,
                        ),
                        builder: (context, paymentSnapshot) {
                          if (!paymentSnapshot.hasData ||
                              paymentSnapshot.data!.docs.isEmpty) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No payments yet. Tap Add Payment below.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: paymentSnapshot.data!.docs.map((paymentDoc) {
                              final payment = paymentDoc.data();
                              final ts = payment['date'];
                              final date = ts is Timestamp ? ts.toDate() : null;
                              final mode = payment['mode']?.toString() ?? 'Cash';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                                    child: const Icon(
                                      Icons.payments,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  title: Text(
                                    '₹ ${payment['amount'] ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: Text(
                                    date != null
                                        ? '${date.day}/${date.month}/${date.year} · $mode'
                                        : mode,
                                  ),
                                  trailing: widget.role == 'admin'
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              deletePayment(paymentDoc.id),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
