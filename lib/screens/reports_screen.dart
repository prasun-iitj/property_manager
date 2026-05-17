import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import '../services/property_analytics_service.dart';
import '../utils/ledger_calculator.dart';
import '../widgets/property_chart.dart';
import 'ledger/ledger_analytics_screen.dart';
import 'ledger/ledger_dashboard.dart';
import 'site_list_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DashboardService _dashboard = DashboardService();
  final PropertyAnalyticsService _propertyAnalytics = PropertyAnalyticsService();

  bool _loading = true;
  PropertyGlobalStats? _property;
  LedgerOverviewStats? _ledger;
  List<SiteSummary> _topSites = [];
  Map<int, PropertyMonthBucket> _monthly = {};
  int _year = DateTime.now().year;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _propertyAnalytics.loadGlobalStats(),
        _dashboard.loadLedgerOverview(),
        _propertyAnalytics.loadSiteSummaries(),
        _propertyAnalytics.loadPropertyMonthlyBreakdown(_year),
      ]);
      if (!mounted) return;
      setState(() {
        _property = results[0] as PropertyGlobalStats;
        _ledger = results[1] as LedgerOverviewStats;
        _topSites = (results[2] as List<SiteSummary>).take(5).toList();
        _monthly = results[3] as Map<int, PropertyMonthBucket>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadChartOnly() async {
    final monthly =
        await _propertyAnalytics.loadPropertyMonthlyBreakdown(_year);
    if (mounted) setState(() => _monthly = monthly);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        title: const Text('Insights Hub'),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompareBanner(),
                    const SizedBox(height: 16),
                    _sectionTitle('Property collections', Icons.apartment),
                    const SizedBox(height: 10),
                    _propertyPanel(),
                    const SizedBox(height: 20),
                    _sectionTitle('Collection trend', Icons.show_chart),
                    const SizedBox(height: 10),
                    _chartCard(),
                    if (_selectedMonth != null) ...[
                      const SizedBox(height: 10),
                      _monthDetail(_selectedMonth!),
                    ],
                    const SizedBox(height: 20),
                    _sectionTitle('Top sites by outstanding', Icons.leaderboard),
                    const SizedBox(height: 10),
                    ..._topSites.map(_siteRankTile),
                    const SizedBox(height: 20),
                    _sectionTitle('Money ledger snapshot', Icons.account_balance_wallet),
                    const SizedBox(height: 10),
                    _ledgerPanel(),
                    const SizedBox(height: 16),
                    _linkTile(
                      'Open ledger dashboard',
                      'Charts, lending & borrowing',
                      Icons.dashboard,
                      const Color(0xFF0F766E),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LedgerDashboard()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _linkTile(
                      'Detailed ledger analytics',
                      'Interest earned vs paid',
                      Icons.analytics,
                      const Color(0xFF6D28D9),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LedgerAnalyticsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _linkTile(
                      'Property hub',
                      'Sites, plots, customers',
                      Icons.location_city,
                      const Color(0xFF2563EB),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SiteListScreen(role: 'admin'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6D28D9)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCompareBanner() {
    final p = _property;
    final l = _ledger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF9333EA)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business snapshot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bannerStat(
                  'Property due',
                  LedgerMoneyFormat.rupees(p?.totalOutstanding ?? 0),
                  Icons.home_work,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bannerStat(
                  'Ledger net',
                  LedgerMoneyFormat.rupees(l?.netPosition ?? 0),
                  Icons.swap_horiz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                FittedBox(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _propertyPanel() {
    final p = _property;
    return _insightCard(
      color: const Color(0xFF2563EB),
      children: [
        _metricRow('Plots sold', '${p?.occupiedPlots ?? 0} / ${p?.totalPlots ?? 0}'),
        _metricRow('Vacant plots', '${p?.vacantPlots ?? 0}'),
        _metricRow('Collected today', LedgerMoneyFormat.rupees(p?.todayCollection ?? 0)),
        _metricRow('Collected this month', LedgerMoneyFormat.rupees(p?.monthCollection ?? 0)),
        _metricRow('EMI overdue', '${p?.emiDueCount ?? 0} customers'),
      ],
    );
  }

  Widget _ledgerPanel() {
    final l = _ledger;
    return _insightCard(
      color: const Color(0xFF0F766E),
      children: [
        _metricRow('Total lent', LedgerMoneyFormat.rupees(l?.totalLentPrincipal ?? 0)),
        _metricRow('Total borrowed', LedgerMoneyFormat.rupees(l?.totalBorrowedPrincipal ?? 0)),
        _metricRow('Lending balance', LedgerMoneyFormat.rupees(l?.totalLendingRemaining ?? 0)),
        _metricRow('Borrowing balance', LedgerMoneyFormat.rupees(l?.totalBorrowingRemaining ?? 0)),
        _metricRow('Interest net', LedgerMoneyFormat.rupees(l?.interestNet ?? 0)),
      ],
    );
  }

  Widget _insightCard({required Color color, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chartCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: PropertyCollectionsChart(
        buckets: _monthly,
        year: _year,
        selectedMonth: _selectedMonth,
        barColor: const Color(0xFF7C3AED),
        onYearChanged: (y) {
          setState(() {
            _year = y;
            _selectedMonth = null;
          });
          _loadChartOnly();
        },
        onMonthSelected: (m) => setState(() => _selectedMonth = m),
      ),
    );
  }

  Widget _monthDetail(int month) {
    const labels = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final b = _monthly[month] ?? const PropertyMonthBucket();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B4FE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${labels[month]} $_year',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${LedgerMoneyFormat.rupees(b.collected)} · ${b.paymentCount} payments',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _siteRankTile(SiteSummary site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
          child: Text(
            site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${site.plotCount} plots · ${site.occupied} sold · '
          'Month ${LedgerMoneyFormat.rupees(site.monthCollection)}',
        ),
        trailing: Text(
          LedgerMoneyFormat.rupees(site.outstanding),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _linkTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: color),
        onTap: onTap,
      ),
    );
  }
}
