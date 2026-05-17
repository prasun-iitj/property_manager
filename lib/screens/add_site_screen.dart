import 'package:flutter/material.dart';
import '../models/site_model.dart';
import '../services/site_service.dart';

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
  final SiteService _siteService = SiteService();
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
      final doc = await _siteService.getSite(widget.siteId!);

      if (doc.exists) {
        final site = SiteModel.fromMap(doc.id, doc.data()!);
        nameController.text = site.name;
        locationController.text = site.location;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load site details")),
      );
    }
  }

  Future<void> saveSite() async {
    String name = nameController.text.trim();
    String location = locationController.text.trim();

    if (name.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final site = SiteModel(
        id: widget.siteId ?? '',
        name: name,
        location: location,
      );

      await _siteService.saveSite(
        site: site,
        siteId: widget.siteId,
        isEdit: widget.isEdit,
      );
      if (!mounted) return;

      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save site. Please try again.")),
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
                      : Text(widget.isEdit ? "Update Site" : "Save Site"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}