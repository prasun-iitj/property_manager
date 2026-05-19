import 'package:flutter/material.dart';
import '../services/app_cache.dart';
import '../services/search_service.dart';
import '../services/property_analytics_service.dart';
import '../utils/ledger_calculator.dart';
import '../widgets/empty_state.dart';
import 'customer_detail_screen.dart';

class SiteCustomerSearchScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String role;

  const SiteCustomerSearchScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.role,
  });

  @override
  State<SiteCustomerSearchScreen> createState() =>
      _SiteCustomerSearchScreenState();
}

class _SiteCustomerSearchScreenState extends State<SiteCustomerSearchScreen> {
  final SearchService _searchService = SearchService();
  final PropertyAnalyticsService _analytics = PropertyAnalyticsService();
  final TextEditingController _searchController = TextEditingController();

  List<CustomerSearchResult> _results = [];
  PropertyGlobalStats? _siteContext;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final cached = AppCache.instance.plotSummaries(widget.siteId);
    if (cached != null && mounted) {
      _applyContext(cached);
    }

    final plots = await _analytics.loadPlotSummaries(widget.siteId);
    if (!mounted) return;
    _applyContext(plots);
  }

  void _applyContext(List<PlotSummary> plots) {
    final occupied = plots.where((p) => p.hasCustomer).length;
    final outstanding = plots.fold<int>(0, (s, p) => s + p.remaining);
    setState(() {
      _siteContext = PropertyGlobalStats(
        siteCount: 1,
        totalPlots: plots.length,
        occupiedPlots: occupied,
        vacantPlots: plots.length - occupied,
        totalOutstanding: outstanding,
      );
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _searchService.searchCustomersInSite(
        siteId: widget.siteId,
        query: query,
      );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _siteContext;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Search · ${widget.siteName}'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _ctxStat('Plots', '${ctx?.totalPlots ?? '—'}'),
                _ctxStat('Sold', '${ctx?.occupiedPlots ?? '—'}'),
                _ctxStat(
                  'Due',
                  LedgerMoneyFormat.rupees(ctx?.totalOutstanding ?? 0),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Customer name or phone',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _results = []);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _runSearch(),
              onChanged: (v) {
                if (v.trim().length >= 2) _runSearch();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? EmptyState(
                        icon: Icons.person_search,
                        title: 'Find a customer',
                        message:
                            'Type at least 2 characters of name or phone to search this site.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final c = _results[index];
                          final pct = c.totalPrice > 0
                              ? (c.totalPaid / c.totalPrice).clamp(0.0, 1.0)
                              : 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(
                                      siteId: c.siteId,
                                      plotId: c.plotId,
                                      plotNumber: c.plotNumber,
                                      role: widget.role,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(0xFF2563EB),
                                          child: Text(
                                            c.name.isNotEmpty
                                                ? c.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.name.isEmpty ? 'Unnamed' : c.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Plot ${c.plotNumber} · ${c.phone}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              LedgerMoneyFormat.rupees(c.remaining),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right, size: 18),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 5,
                                        backgroundColor: Colors.grey.shade200,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _ctxStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
