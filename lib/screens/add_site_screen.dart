import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSiteScreen extends StatefulWidget {
  final String? siteId;
  final bool isEdit;

  const AddSiteScreen({
    super.key,
    this.siteId,
    this.isEdit = false,
  });

  @override
  State<AddSiteScreen> createState() => _AddSiteScreenState();
}

class _AddSiteScreenState extends State<AddSiteScreen> {
  final nameController = TextEditingController();
  final locationController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.siteId != null) {
      loadSiteData();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> loadSiteData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('sites')
          .doc(widget.siteId)
          .get();

      if (doc.exists) {
        var data = doc.data()!;
        nameController.text = data['name'] ?? '';
        locationController.text = data['location'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load site data")),
      );
    }
  }

  Future<void> saveSite() async {
    String name = nameController.text.trim();
    String location = locationController.text.trim();

    if (name.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (widget.isEdit && widget.siteId != null) {
        // 🔹 Update existing site
        await FirebaseFirestore.instance
            .collection('sites')
            .doc(widget.siteId)
            .set({
          'name': name,
          'location': location,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // 🔹 Create new site
        await FirebaseFirestore.instance
            .collection('sites')
            .add({
          'name': name,
          'location': location,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? "Edit Site" : "Add Site"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Site Name",
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: "Location",
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveSite,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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