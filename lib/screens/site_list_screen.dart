import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_site_screen.dart';
import 'plot_list_screen.dart';
import '../widgets/breadcrumb.dart';

class SiteListScreen extends StatefulWidget {
  final String role;

  const SiteListScreen({super.key, required this.role});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {

  Future<void> deleteSite(String siteId) async {

    final passwordController = TextEditingController();

    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Admin Verification Required"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Enter your password to permanently delete this site and all its data."),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Admin Password",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Verify & Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      final firestore = FirebaseFirestore.instance;

      var plotsSnapshot = await firestore
          .collection('sites')
          .doc(siteId)
          .collection('plots')
          .get();

      for (var plotDoc in plotsSnapshot.docs) {

        var paymentsSnapshot = await firestore
            .collection('sites')
            .doc(siteId)
            .collection('plots')
            .doc(plotDoc.id)
            .collection('customer')
            .doc('details')
            .collection('payments')
            .get();

        for (var payment in paymentsSnapshot.docs) {
          await payment.reference.delete();
        }

        await firestore
            .collection('sites')
            .doc(siteId)
            .collection('plots')
            .doc(plotDoc.id)
            .collection('customer')
            .doc('details')
            .delete();

        await plotDoc.reference.delete();
      }

      await firestore.collection('sites').doc(siteId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Site deleted successfully")),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wrong password. Deletion cancelled."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sites"),
        actions: [
          if (widget.role == "admin")
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSiteScreen(),
                  ),
                );
                setState(() {});
              },
            ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ✅ BREADCRUMB ADDED HERE
          Padding(
            padding: const EdgeInsets.all(10),
            child: Breadcrumb(
              items: [
                BreadcrumbItem(
                  label: "Home",
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(
                  label: "Sites",
                ),
              ],
            ),
          ),

          // ✅ LIST CONTENT
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sites')
                  .snapshots(),
              builder: (context, snapshot) {

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No Sites Found"));
                }

                return ListView(
                  padding: const EdgeInsets.all(10),
                  children: snapshot.data!.docs.map((doc) {

                    final data =
                        doc.data() as Map<String, dynamic>;

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(data['name'] ?? ''),
                        subtitle: Text(data['location'] ?? ''),
                        trailing: widget.role == "admin"
                            ? PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == "edit") {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddSiteScreen(
                                          siteId: doc.id,
                                          isEdit: true,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  } else if (value == "delete") {
                                    await deleteSite(doc.id);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: "edit",
                                    child: Text("Edit"),
                                  ),
                                  PopupMenuItem(
                                    value: "delete",
                                    child: Text(
                                      "Delete",
                                      style: TextStyle(
                                          color: Colors.red),
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlotListScreen(
                                siteId: doc.id,
                                siteName: data['name'],
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