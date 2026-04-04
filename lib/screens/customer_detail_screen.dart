import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_customer_screen.dart';
import 'add_payment_screen.dart';
import 'document_upload_screen.dart'; // ✅ NEW IMPORT
import '../widgets/breadcrumb.dart';

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

  String get customerId => "${widget.siteId}_${widget.plotId}"; // ✅ UNIQUE ID

  Future<void> deleteCustomer() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Customer"),
        content: const Text(
          "Are you sure? This will remove customer and all payments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('sites')
          .doc(widget.siteId)
          .collection('plots')
          .doc(widget.plotId)
          .collection('customer')
          .doc('details')
          .delete();

      Navigator.pop(context);
    }
  }

  Future<void> deletePayment(String paymentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Payment"),
        content: const Text("Are you sure you want to delete this payment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('sites')
          .doc(widget.siteId)
          .collection('plots')
          .doc(widget.plotId)
          .collection('customer')
          .doc('details')
          .collection('payments')
          .doc(paymentId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment deleted")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Plot ${widget.plotNumber}"),
        actions: [
          if (widget.role == "admin")
            IconButton(
              icon: const Icon(Icons.edit),
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
          if (widget.role == "admin")
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteCustomer,
            ),
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPaymentScreen(
                    siteId: widget.siteId,
                    plotId: widget.plotId,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: const EdgeInsets.all(10),
            child: Breadcrumb(
              items: [
                BreadcrumbItem(label: "Home", onTap: () => Navigator.pop(context)),
                BreadcrumbItem(label: "Sites", onTap: () => Navigator.pop(context)),
                BreadcrumbItem(label: "Plots", onTap: () => Navigator.pop(context)),
                BreadcrumbItem(label: "Customer"),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('sites')
                  .doc(widget.siteId)
                  .collection('plots')
                  .doc(widget.plotId)
                  .collection('customer')
                  .doc('details')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("No Customer Assigned"));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                int totalPrice = data['totalPrice'] ?? 0;
                int totalPaid = data['totalPaid'] ?? 0;
                int remaining = data['remaining'] ?? 0;

                double progress = totalPrice > 0 ? totalPaid / totalPrice : 0;

                DateTime? nextEmi;
                bool emiDue = false;

                if (data['nextEmiDate'] != null) {
                  nextEmi = (data['nextEmiDate'] as Timestamp).toDate();
                  if (DateTime.now().isAfter(nextEmi)) emiDue = true;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text("Name: ${data['name'] ?? '-'}"),
                      Text("Phone: ${data['phone'] ?? '-'}"),

                      const SizedBox(height: 15),

                      // ✅ DOCUMENT BUTTON ADDED
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Upload Documents"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DocumentUploadScreen(
                                customerId: customerId,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Price: ₹ $totalPrice"),
                              Text("Total Paid: ₹ $totalPaid"),
                              Text("Remaining: ₹ $remaining"),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: progress),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (nextEmi != null)
                        Text(
                          "Next EMI: ${nextEmi.day}/${nextEmi.month}/${nextEmi.year}",
                          style: TextStyle(
                            color: emiDue ? Colors.red : Colors.black,
                            fontWeight:
                                emiDue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),

                      const SizedBox(height: 25),
                      const Text(
                        "Payment History",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sites')
                            .doc(widget.siteId)
                            .collection('plots')
                            .doc(widget.plotId)
                            .collection('customer')
                            .doc('details')
                            .collection('payments')
                            .orderBy('date', descending: true)
                            .snapshots(),
                        builder: (context, paymentSnapshot) {
                          if (!paymentSnapshot.hasData ||
                              paymentSnapshot.data!.docs.isEmpty) {
                            return const Text("No Payments Yet");
                          }

                          return Column(
                            children:
                                paymentSnapshot.data!.docs.map((paymentDoc) {
                              final payment =
                                  paymentDoc.data() as Map<String, dynamic>;

                              Timestamp? ts = payment['date'];
                              DateTime? date = ts?.toDate();

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 3,
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF1E3C72),
                                    child: Icon(Icons.payment, color: Colors.white),
                                  ),
                                  title: Text(
                                    "₹ ${payment['amount'] ?? 0}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    date != null
                                        ? "${date.day}/${date.month}/${date.year}  |  ${payment['mode'] ?? 'Cash'}"
                                        : "No Date  |  ${payment['mode'] ?? 'Cash'}",
                                  ),
                                  trailing: widget.role == "admin"
                                      ? IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
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
          ),
        ],
      ),
    );
  }
}