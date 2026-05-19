import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_site_screen.dart';
import 'plot_list_screen.dart';
import 'site_customer_search_screen.dart';
import '../services/app_cache.dart';
import '../services/site_service.dart';
import '../services/property_analytics_service.dart';
import '../utils/ledger_calculator.dart';
import '../utils/session_actions.dart';
import '../widgets/role_access_banner.dart';

class SiteListScreen extends StatefulWidget {
  final String role;

  const SiteListScreen({super.key, required this.role});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  final SiteService _siteService = SiteService();
  final PropertyAnalyticsService _analytics = PropertyAnalyticsService();
  final TextEditingController _searchController = TextEditingController();

  PropertyGlobalStats? _global;
  List<SiteSummary> _sites = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool force = false, bool background = false}) async {
    final cachedGlobal = AppCache.instance.propertyGlobal;
    final cachedSites = AppCache.instance.siteSummaries;
    if (!force && cachedGlobal != null && cachedSites != null) {
      setState(() {
        _global = cachedGlobal;
        _sites = cachedSites;
        _loading = false;
        _loadError = null;
      });
    } else if (!background) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait([
        _analytics.loadGlobalStats(forceRefresh: force),
        _analytics.loadSiteSummaries(forceRefresh: force),
      ]);
      if (!mounted) return;
      setState(() {
        _global = results[0] as PropertyGlobalStats;
        _sites = results[1] as List<SiteSummary>;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load property data: $e'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await signOutCompletely();
  }

  Future<void> deleteSite(String siteId) async {
    final passwordController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin Verification Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your password to permanently delete this site and all its data.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Admin Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify & Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      passwordController.dispose();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await _siteService.deleteSiteCascade(siteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site deleted successfully')),
      );
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong password. Deletion cancelled.')),
      );
    } finally {
      passwordController.dispose();
    }
  }

  List<SiteSummary> get _filteredSites {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _sites;
    return _sites
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.location.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Property Hub'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
          if (widget.role == 'admin')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSiteScreen()),
                );
                _refresh();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: RoleAccessBanner(
                      role: widget.role,
                      email: FirebaseAuth.instance.currentUser?.email,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildHero()),
                  if (_loadError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Data error — tap refresh or sign out and use admin account.',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildSearch()),
                  if (_filteredSites.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _sites.isEmpty
                              ? 'No sites found. Sign out and log in with admin if you need full access.'
                              : 'No sites match your search',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _siteCard(_filteredSites[i]),
                          childCount: _filteredSites.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    final g = _global;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apartment, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Property overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat('Sites', '${g?.siteCount ?? 0}'),
              _heroStat('Plots', '${g?.totalPlots ?? 0}'),
              _heroStat(
                'Occupied',
                '${g != null ? (g.occupancyRate * 100).round() : 0}%',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _heroStat(
                'Outstanding',
                LedgerMoneyFormat.rupees(g?.totalOutstanding ?? 0),
              ),
              _heroStat(
                'This month',
                LedgerMoneyFormat.rupees(g?.monthCollection ?? 0),
              ),
              _heroStat('EMI due', '${g?.emiDueCount ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search sites by name or location',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _siteCard(SiteSummary site) {
    final occ = site.plotCount > 0 ? site.occupied / site.plotCount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlotListScreen(
                siteId: site.siteId,
                siteName: site.name,
                role: widget.role,
              ),
            ),
          ).then((_) => _refresh(background: true));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_city, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          site.location.isEmpty ? 'No location' : site.location,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'search') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SiteCustomerSearchScreen(
                              siteId: site.siteId,
                              siteName: site.name,
                              role: widget.role,
                            ),
                          ),
                        );
                      } else if (v == 'edit' && widget.role == 'admin') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddSiteScreen(
                              siteId: site.siteId,
                              isEdit: true,
                            ),
                          ),
                        );
                        _refresh();
                      } else if (v == 'delete' && widget.role == 'admin') {
                        await deleteSite(site.siteId);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'search', child: Text('Search customers')),
                      if (widget.role == 'admin')
                        const PopupMenuItem(value: 'edit', child: Text('Edit site')),
                      if (widget.role == 'admin')
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occ.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('${site.plotCount} plots', Icons.grid_view),
                  const SizedBox(width: 8),
                  _chip('${site.occupied} sold', Icons.person),
                  const Spacer(),
                  Text(
                    LedgerMoneyFormat.rupees(site.outstanding),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
