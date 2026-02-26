import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_plot_screen.dart';
import 'customer_detail_screen.dart';
import 'site_customer_search_screen.dart';

class PlotListScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String role;

  const PlotListScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.role,
  });

  @override
  State<PlotListScreen> createState() => _PlotListScreenState();
}

class _PlotListScreenState extends State<PlotListScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Plots - ${widget.siteName}"),
        actions: [
          if (widget.role == "admin")
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPlotScreen(siteId: widget.siteId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search Plot Number",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sites')
                  .doc(widget.siteId)
                  .collection('plots')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var plots = snapshot.data!.docs.where((doc) {
                  String plotNumber = doc['plotNumber'].toString();
                  return plotNumber.toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  );
                }).toList();

                if (plots.isEmpty) {
                  return const Center(child: Text("No Results"));
                }

                return ListView(
                  padding: const EdgeInsets.all(10),
                  children: plots.map((doc) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text("Plot: ${doc['plotNumber']}"),
                        subtitle: Text("₹ ${doc['totalPrice'] ?? 0}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(
                                siteId: widget.siteId,
                                plotId: doc.id,
                                plotNumber: doc['plotNumber'],
                                role: widget.role,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
