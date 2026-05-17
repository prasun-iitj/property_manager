import 'package:flutter/material.dart';
import 'add_plot_screen.dart';
import 'customer_detail_screen.dart';
import 'site_customer_search_screen.dart';
import '../services/plot_service.dart';
import '../services/property_analytics_service.dart';
import '../utils/ledger_calculator.dart';

enum _PlotFilter { all, occupied, vacant, emiDue }

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
  final PropertyAnalyticsService _analytics = PropertyAnalyticsService();
  final TextEditingController _searchController = TextEditingController();

  List<PlotSummary> _plots = [];
  _PlotFilter _filter = _PlotFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plots = await _analytics.loadPlotSummaries(widget.siteId);
      if (mounted) setState(() => _plots = plots);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PlotSummary> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _plots.where((p) {
      if (q.isNotEmpty &&
          !p.plotNumber.toLowerCase().contains(q) &&
          !p.customerName.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case _PlotFilter.occupied:
          return p.hasCustomer;
        case _PlotFilter.vacant:
          return !p.hasCustomer;
        case _PlotFilter.emiDue:
          return p.emiDue;
        case _PlotFilter.all:
          return true;
      }
    }).toList();
  }

  int get _outstanding =>
      _plots.where((p) => p.hasCustomer).fold(0, (s, p) => s + p.remaining);

  /// Plot numbers that appear more than once in this site.
  Set<String> get _duplicatePlotKeys {
    final counts = <String, int>{};
    for (final p in _plots) {
      final key = PlotService.normalizePlotNumber(p.plotNumber);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();
  }

  bool _isDuplicatePlot(PlotSummary plot) =>
      _duplicatePlotKeys.contains(PlotService.normalizePlotNumber(plot.plotNumber));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.siteName),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SiteCustomerSearchScreen(
                    siteId: widget.siteId,
                    siteName: widget.siteName,
                    role: widget.role,
                  ),
                ),
              );
            },
          ),
          if (widget.role == 'admin')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPlotScreen(siteId: widget.siteId),
                  ),
                );
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildSiteStrip()),
                  if (_duplicatePlotKeys.isNotEmpty)
                    SliverToBoxAdapter(child: _buildDuplicateBanner()),
                  SliverToBoxAdapter(child: _buildFilters()),
                  if (_filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No plots match filters')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => _plotCard(_filtered[i]),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSiteStrip() {
    final occupied = _plots.where((p) => p.hasCustomer).length;
    final emiDue = _plots.where((p) => p.emiDue).length;
    final vacant = _plots.length - occupied;

    return Container(
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
          _stripStat('Plots', '${_plots.length}'),
          _stripStat('Sold', '$occupied'),
          _stripStat('Vacant', '$vacant'),
          _stripStat('Due', '$emiDue'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Outstanding', style: TextStyle(color: Colors.white70, fontSize: 10)),
                Text(
                  LedgerMoneyFormat.rupees(_outstanding),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDuplicateBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Duplicate plot numbers found. Rename or delete one — '
              'new plots cannot reuse an existing number.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search plot or customer name',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', _PlotFilter.all),
                _filterChip('With customer', _PlotFilter.occupied),
                _filterChip('Vacant', _PlotFilter.vacant),
                _filterChip('EMI due', _PlotFilter.emiDue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PlotFilter f) {
    final sel = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: const Color(0xFFDBEAFE),
        checkmarkColor: const Color(0xFF1E40AF),
      ),
    );
  }

  Widget _plotCard(PlotSummary plot) {
    final progress = plot.totalPrice > 0 && plot.hasCustomer
        ? (plot.totalPaid / plot.totalPrice).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(
                siteId: widget.siteId,
                plotId: plot.plotId,
                plotNumber: plot.plotNumber,
                role: widget.role,
              ),
            ),
          ).then((_) => _load());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: plot.hasCustomer
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade400,
                    child: Text(
                      plot.plotNumber.length > 2
                          ? plot.plotNumber.substring(0, 2)
                          : plot.plotNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plot ${plot.plotNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          plot.hasCustomer
                              ? plot.customerName.isEmpty
                                  ? 'Customer (no name)'
                                  : plot.customerName
                              : 'Vacant — tap to assign',
                          style: TextStyle(
                            fontSize: 12,
                            color: plot.hasCustomer
                                ? Colors.grey.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isDuplicatePlot(plot))
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        'Duplicate',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (plot.emiDue)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text(
                        'EMI due',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (plot.hasCustomer) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid ${LedgerMoneyFormat.rupees(plot.totalPaid)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Due ${LedgerMoneyFormat.rupees(plot.remaining)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Price ${LedgerMoneyFormat.rupees(plot.totalPrice)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
