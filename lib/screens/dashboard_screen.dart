import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'site_list_screen.dart';
import 'ledger/ledger_dashboard.dart';
import 'ledger/lending_list_screen.dart';
import 'ledger/borrowing_list_screen.dart';
import 'reports_screen.dart';
import 'admin/manage_team_screen.dart';
import 'admin/backup_settings_screen.dart';
import '../services/app_cache.dart';
import '../services/dashboard_service.dart';
import '../utils/ledger_calculator.dart';
import '../utils/session_actions.dart';
import '../widgets/dashboard_zone.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  bool _loading = true;
  PropertyCollectionStats? _property;
  LedgerOverviewStats? _ledger;

  static const _propertyColors = [Color(0xFF1E3A8A), Color(0xFF2563EB)];
  static const _financeColors = [Color(0xFF0F766E), Color(0xFF14B8A6)];
  static const _insightsColors = [Color(0xFF6D28D9), Color(0xFF9333EA)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false, bool background = false}) async {
    final cachedProperty = AppCache.instance.dashboardProperty;
    final cachedLedger = AppCache.instance.dashboardLedger;
    if (!force && cachedProperty != null && cachedLedger != null) {
      setState(() {
        _property = cachedProperty;
        _ledger = cachedLedger;
        _loading = false;
      });
    } else if (!background) {
      setState(() => _loading = true);
    }

    Object? loadError;
    try {
      final propertyFuture =
          _dashboardService.loadPropertyStats(forceRefresh: force);
      final ledgerFuture =
          _dashboardService.loadLedgerOverview(forceRefresh: force);
      final property = await propertyFuture.catchError((e) {
        loadError ??= e;
        return const PropertyCollectionStats(
          todayCollection: 0,
          monthCollection: 0,
          totalOutstanding: 0,
          paymentCountThisMonth: 0,
        );
      });
      final ledger = await ledgerFuture.catchError((e) {
        loadError ??= e;
        return const LedgerOverviewStats(
          totalLentPrincipal: 0,
          totalBorrowedPrincipal: 0,
          totalLendingRemaining: 0,
          totalBorrowingRemaining: 0,
          interestEarned: 0,
          interestPaid: 0,
          overpaidLoansCount: 0,
        );
      });
      if (!mounted) return;
      setState(() {
        _property = property;
        _ledger = ledger;
      });
      if (loadError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some stats could not load: $loadError'),
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

  Future<void> _pushAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _load(background: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => _pushAndRefresh(const ManageTeamScreen()),
            tooltip: 'Manage team',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => _pushAndRefresh(const BackupSettingsScreen()),
            tooltip: 'Cloud backup',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 900;
                final zones = [
                  _buildPropertyZone(),
                  _buildFinanceZone(),
                  _buildInsightsZone(),
                ];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcomeStrip(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: stacked
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height: constraints.maxWidth < 400
                                        ? 238
                                        : 220,
                                    child: zones[0],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: constraints.maxWidth < 400
                                        ? 318
                                        : 288,
                                    child: zones[1],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: constraints.maxWidth < 400
                                        ? 238
                                        : 220,
                                    child: zones[2],
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: zones[0]),
                                  const SizedBox(width: 10),
                                  Expanded(child: zones[1]),
                                  const SizedBox(width: 10),
                                  Expanded(child: zones[2]),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildWelcomeStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize, color: Color(0xFF475569)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Choose a workspace — property sales, money ledger, or reports',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_ledger != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Text(
                'Net ledger: ${LedgerMoneyFormat.rupees(_ledger!.netPosition)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF047857),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyZone() {
    final p = _property;
    return DashboardZone(
      title: 'Property',
      subtitle: 'Sites · plots · customers',
      icon: Icons.location_city,
      gradient: _propertyColors,
      accent: _propertyColors.first,
      onTap: p == null
          ? null
          : () => _pushAndRefresh(const SiteListScreen(role: 'admin')),
      statsPanel: ZoneStats2x2(
        topLeft: ZoneStatCell(
          label: 'Collected today',
          value: LedgerMoneyFormat.rupees(p?.todayCollection ?? 0),
        ),
        topRight: ZoneStatCell(
          label: 'This month',
          value: LedgerMoneyFormat.rupees(p?.monthCollection ?? 0),
        ),
        bottomLeft: ZoneStatCell(
          label: 'Plot outstanding',
          value: LedgerMoneyFormat.rupees(p?.totalOutstanding ?? 0),
          valueColor: const Color(0xFFFECACA),
        ),
        bottomRight: ZoneStatCell(
          label: 'Payments (month)',
          value: '${p?.paymentCountThisMonth ?? 0}',
        ),
      ),
      actions: [
        ZoneActionButton(
          label: 'Property hub',
          icon: Icons.apartment,
          foreground: _propertyColors.first,
          background: Colors.white,
          onTap: () => _pushAndRefresh(const SiteListScreen(role: 'admin')),
        ),
      ],
    );
  }

  Widget _buildFinanceZone() {
    final l = _ledger;
    final interestNet = l?.interestNet ?? 0;
    return DashboardZone(
      title: 'Finance & Ledger',
      subtitle: 'Lending · borrowing · interest',
      icon: Icons.account_balance_wallet,
      gradient: _financeColors,
      accent: _financeColors.first,
      onTap: l == null
          ? null
          : () => _pushAndRefresh(const LedgerDashboard()),
      statsPanel: ZoneStats2x2(
        topLeft: ZoneStatCell(
          label: 'Lent balance',
          value: LedgerMoneyFormat.rupees(l?.totalLendingRemaining ?? 0),
          valueColor: const Color(0xFFBBF7D0),
        ),
        topRight: ZoneStatCell(
          label: 'Owe balance',
          value: LedgerMoneyFormat.rupees(l?.totalBorrowingRemaining ?? 0),
          valueColor: const Color(0xFFFDE68A),
        ),
        bottomLeft: ZoneStatCell(
          label: 'Interest earned',
          value: LedgerMoneyFormat.rupees(l?.interestEarned ?? 0),
        ),
        bottomRight: ZoneStatCell(
          label: 'Interest paid',
          value: LedgerMoneyFormat.rupees(l?.interestPaid ?? 0),
        ),
        footnote: (interestNet != 0 || (l?.overpaidLoansCount ?? 0) > 0)
            ? '${interestNet >= 0 ? 'Interest surplus' : 'Interest deficit'}: '
                '${LedgerMoneyFormat.rupees(interestNet.abs())}'
                '${(l?.overpaidLoansCount ?? 0) > 0 ? ' · ${l!.overpaidLoansCount} overpaid' : ''}'
            : null,
      ),
      actions: [
        ZoneActionButton(
          label: 'Ledger dashboard',
          icon: Icons.dashboard,
          height: 32,
          foreground: _financeColors.first,
          background: Colors.white,
          onTap: () => _pushAndRefresh(const LedgerDashboard()),
        ),
        Row(
          children: [
            Expanded(
              child: ZoneActionButton(
                label: 'Lending',
                icon: Icons.trending_up,
                height: 30,
                foreground: _financeColors.first,
                background: Colors.white.withValues(alpha: 0.92),
                onTap: () => _pushAndRefresh(const LendingListScreen()),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ZoneActionButton(
                label: 'Borrowing',
                icon: Icons.trending_down,
                height: 30,
                foreground: _financeColors.first,
                background: Colors.white.withValues(alpha: 0.85),
                onTap: () => _pushAndRefresh(const BorrowingListScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsZone() {
    final p = _property;
    final l = _ledger;
    final totalPrincipal =
        (l?.totalLentPrincipal ?? 0) + (l?.totalBorrowedPrincipal ?? 0);

    return DashboardZone(
      title: 'Insights',
      subtitle: 'Reports · overview',
      icon: Icons.insights,
      gradient: _insightsColors,
      accent: _insightsColors.first,
      onTap: () => _pushAndRefresh(const ReportsScreen()),
      statsPanel: ZoneStats2x2(
        topLeft: ZoneStatCell(
          label: 'Ledger principal',
          value: LedgerMoneyFormat.rupees(totalPrincipal),
        ),
        topRight: ZoneStatCell(
          label: 'Property due',
          value: LedgerMoneyFormat.rupees(p?.totalOutstanding ?? 0),
        ),
        bottomLeft: ZoneStatCell(
          label: 'Month collections',
          value: LedgerMoneyFormat.rupees(p?.monthCollection ?? 0),
        ),
        bottomRight: ZoneStatCell(
          label: 'Lent / borrowed',
          value:
              '${LedgerMoneyFormat.rupees(l?.totalLentPrincipal ?? 0)} / ${LedgerMoneyFormat.rupees(l?.totalBorrowedPrincipal ?? 0)}',
        ),
      ),
      actions: [
        ZoneActionButton(
          label: 'Open reports',
          icon: Icons.bar_chart,
          foreground: _insightsColors.first,
          background: Colors.white,
          onTap: () => _pushAndRefresh(const ReportsScreen()),
        ),
      ],
    );
  }
}
