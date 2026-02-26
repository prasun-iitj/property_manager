import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SiteCustomerSearchScreen extends StatefulWidget {
  final String siteId;

  const SiteCustomerSearchScreen({super.key, required this.siteId});

  @override
  State<SiteCustomerSearchScreen> createState() =>
      _SiteCustomerSearchScreenState();
}

class _SiteCustomerSearchScreenState
    extends State<SiteCustomerSearchScreen> {
  final TextEditingController searchController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Customer")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search by Name or Phone",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
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
                  return const Center(
                      child: CircularProgressIndicator());
                }

                List results = [];

                for (var plot in snapshot.data!.docs) {
                  var customerRef = plot.reference
                      .collection('customer')
                      .doc('details');

                  results.add({
                    'plotId': plot.id,
                    'plotNumber': plot['plotNumber'],
                    'customerRef': customerRef
                  });
                }

                return FutureBuilder(
                  future: Future.wait(results.map((r) =>
                      r['customerRef'].get())),
                  builder: (context, customerSnapshot) {
                    if (!customerSnapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    List filtered = [];

                    for (int i = 0;
                        i < customerSnapshot.data!.length;
                        i++) {
                      var doc = customerSnapshot.data![i];
                      if (!doc.exists) continue;

                      var data =
                          doc.data() as Map<String, dynamic>;

                      String name =
                          (data['name'] ?? "").toLowerCase();
                      String phone =
                          (data['phone'] ?? "").toLowerCase();

                      if (name.contains(searchController.text
                              .toLowerCase()) ||
                          phone.contains(searchController.text
                              .toLowerCase())) {
                        filtered.add({
                          'plotNumber':
                              results[i]['plotNumber'],
                          'name': data['name'],
                          'phone': data['phone'],
                        });
                      }
                    }

                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text("No Results"));
                    }

                    return ListView(
                      children: filtered.map((c) {
                        return ListTile(
                          title: Text(c['name']),
                          subtitle: Text(
                              "Plot: ${c['plotNumber']} | ${c['phone']}"),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}