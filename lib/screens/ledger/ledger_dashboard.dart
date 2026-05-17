import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'lending_list_screen.dart';
import 'borrowing_list_screen.dart';
import '../../services/backup_service.dart';
import '../../services/dashboard_service.dart';
import '../../utils/ledger_calculator.dart';

enum _ChartMode { combined, lending, borrowing, net }

class LedgerDashboard extends StatefulWidget {
  const LedgerDashboard({super.key});

  @override
  State<LedgerDashboard> createState() => _LedgerDashboardState();
}

class _LedgerDashboardState extends State<LedgerDashboard> {
  final DashboardService _dashboard = DashboardService();

  bool _loading = true;
  LedgerOverviewStats? _overview;
  Map<int, LedgerMonthBucket> _buckets = {};
  int _year = DateTime.now().year;
  _ChartMode _mode = _ChartMode.combined;
  int? _selectedMonth;

  static const _monthLabels = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dashboard.loadLedgerOverview(),
        _dashboard.loadLedgerMonthlyBreakdown(_year),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as LedgerOverviewStats;
        _buckets = results[1] as Map<int, LedgerMonthBucket>;
        _selectedMonth ??= _defaultHighlightMonth();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _defaultHighlightMonth() {
    final now = DateTime.now();
    if (_year == now.year) return now.month;
    for (var m = 12; m >= 1; m--) {
      final b = _buckets[m];
      if (b != null && (b.lendingIn + b.borrowingOut) > 0) return m;
    }
    return 1;
  }

  double _chartMaxY() {
    var maxVal = 0.0;
    for (var m = 1; m <= 12; m++) {
      maxVal = [
        maxVal,
        _barHeight(m, _ChartMode.lending),
        _barHeight(m, _ChartMode.borrowing),
        _barHeight(m, _ChartMode.net).abs(),
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxVal <= 0) return 10000;
    final mag = maxVal * 1.15;
    if (mag >= 100000) return ((mag / 50000).ceil() * 50000).toDouble();
    if (mag >= 10000) return ((mag / 10000).ceil() * 10000).toDouble();
    return ((mag / 1000).ceil() * 1000).toDouble();
  }

  double _barHeight(int month, _ChartMode mode) {
    final b = _buckets[month] ?? const LedgerMonthBucket();
    switch (mode) {
      case _ChartMode.lending:
        return b.lendingIn.toDouble();
      case _ChartMode.borrowing:
        return b.borrowingOut.toDouble();
      case _ChartMode.net:
        return b.netInflow.abs().toDouble();
      case _ChartMode.combined:
        return (b.lendingIn + b.borrowingOut).toDouble();
    }
  }

  String _axisLabel(double value) {
    if (value <= 0) return '0';
    if (value >= 100000) {
      final l = value / 100000;
      return l == l.roundToDouble() ? '${l.toInt()}L' : '${l.toStringAsFixed(1)}L';
    }
    if (value >= 1000) return '${(value / 1000).round()}k';
    return value.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ledger Dashboard'),
        backgroundColor: const Color(0xFF0F766E),
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
                    _buildActionRow(),
                    const SizedBox(height: 20),
                    _buildOverviewSection(),
                    const SizedBox(height: 24),
                    _buildChartSection(),
                    if (_selectedMonth != null) ...[
                      const SizedBox(height: 12),
                      _buildMonthDetailCard(_selectedMonth!),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _navButton(
            'Lending',
            Icons.trending_up,
            const Color(0xFF2563EB),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LendingListScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _navButton(
            'Borrowing',
            Icons.trending_down,
            const Color(0xFFDC2626),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BorrowingListScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _navButton(
            'Backup',
            Icons.backup,
            const Color(0xFF475569),
            () => BackupService.exportLedgerBackup(),
          ),
        ),
      ],
    );
  }

  Widget _navButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final o = _overview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 700 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _statCard(
                  'Lent (principal)',
                  LedgerMoneyFormat.rupees(o?.totalLentPrincipal ?? 0),
                  Icons.arrow_upward,
                  const Color(0xFF2563EB),
                ),
                _statCard(
                  'Borrowed (principal)',
                  LedgerMoneyFormat.rupees(o?.totalBorrowedPrincipal ?? 0),
                  Icons.arrow_downward,
                  const Color(0xFFDC2626),
                ),
                _statCard(
                  'Net position',
                  LedgerMoneyFormat.rupees(o?.netPosition ?? 0),
                  Icons.balance,
                  const Color(0xFF0D9488),
                ),
                _statCard(
                  'Interest (earned − paid)',
                  LedgerMoneyFormat.rupees(o?.interestNet ?? 0),
                  Icons.percent,
                  const Color(0xFF059669),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    final yearTotalIn = _buckets.values.fold<int>(0, (s, b) => s + b.lendingIn);
    final yearTotalOut =
        _buckets.values.fold<int>(0, (s, b) => s + b.borrowingOut);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cash flow by month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            DropdownButton<int>(
              value: _year,
              underline: const SizedBox.shrink(),
              items: List.generate(5, (i) {
                final y = DateTime.now().year - i;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: (y) {
                if (y == null) return;
                setState(() {
                  _year = y;
                  _selectedMonth = null;
                });
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _modeChip('Combined', _ChartMode.combined),
            _modeChip('Lending in', _ChartMode.lending),
            _modeChip('Borrowing out', _ChartMode.borrowing),
            _modeChip('Net flow', _ChartMode.net),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendDot(const Color(0xFF2563EB), 'Lending collected'),
            const SizedBox(width: 14),
            _legendDot(const Color(0xFFDC2626), 'Borrowing paid'),
            const Spacer(),
            Text(
              '$_year · In ${LedgerMoneyFormat.rupees(yearTotalIn)} · Out ${LedgerMoneyFormat.rupees(yearTotalOut)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _buildChart(),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a bar for interest vs principal breakdown',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _modeChip(String label, _ChartMode mode) {
    final selected = _mode == mode;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      selectedColor: const Color(0xFFCCFBF1),
      checkmarkColor: const Color(0xFF0F766E),
    );
  }

  Widget _buildChart() {
    final maxY = _chartMaxY();
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY + 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _axisLabel(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final m = value.toInt();
                if (m < 1 || m > 12) return const SizedBox.shrink();
                final selected = _selectedMonth == m;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _monthLabels[m],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected
                          ? const Color(0xFF0F766E)
                          : Colors.grey.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(12, (i) => _barGroup(i + 1)),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              return;
            }
            final month = response.spot!.touchedBarGroup.x;
            setState(() => _selectedMonth = month);
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipBgColor: const Color(0xFF0F172A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final m = group.x;
              final b = _buckets[m] ?? const LedgerMonthBucket();
              final isLending = rodIndex == 0;
              final label = isLending ? 'Lending in' : 'Borrowing out';
              final amount = isLending ? b.lendingIn : b.borrowingOut;
              return BarTooltipItem(
                '$label\n${LedgerMoneyFormat.rupees(amount)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int month) {
    final b = _buckets[month] ?? const LedgerMonthBucket();
    final selected = _selectedMonth == month;

    if (_mode == _ChartMode.lending) {
      return BarChartGroupData(
        x: month,
        barRods: [
          _rod(b.lendingIn.toDouble(), const Color(0xFF2563EB), selected),
        ],
      );
    }
    if (_mode == _ChartMode.borrowing) {
      return BarChartGroupData(
        x: month,
        barRods: [
          _rod(b.borrowingOut.toDouble(), const Color(0xFFDC2626), selected),
        ],
      );
    }
    if (_mode == _ChartMode.net) {
      final net = b.netInflow;
      final color = net >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
      return BarChartGroupData(
        x: month,
        barRods: [_rod(net.abs().toDouble(), color, selected)],
      );
    }

    // Combined: grouped lending + borrowing
    return BarChartGroupData(
      x: month,
      barsSpace: 4,
      barRods: [
        _rod(b.lendingIn.toDouble(), const Color(0xFF2563EB), selected),
        _rod(b.borrowingOut.toDouble(), const Color(0xFFDC2626), selected),
      ],
    );
  }

  BarChartRodData _rod(double toY, Color color, bool selected) {
    return BarChartRodData(
      toY: toY,
      color: color.withValues(alpha: selected ? 1 : 0.75),
      width: _mode == _ChartMode.combined ? 10 : 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      borderSide: selected
          ? const BorderSide(color: Color(0xFF0F172A), width: 1.5)
          : BorderSide.none,
    );
  }

  Widget _buildMonthDetailCard(int month) {
    final b = _buckets[month] ?? const LedgerMonthBucket();
    final name = _monthLabels[month];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F766E).withValues(alpha: 0.08),
            const Color(0xFF2563EB).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name $_year — breakdown',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _detailColumn(
                  'Lending collected',
                  b.lendingIn,
                  b.lendingInterest,
                  b.lendingPrincipal,
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _detailColumn(
                  'Borrowing paid',
                  b.borrowingOut,
                  b.borrowingInterest,
                  b.borrowingPrincipal,
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net cash flow (in − out)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  LedgerMoneyFormat.rupees(b.netInflow),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: b.netInflow >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailColumn(
    String title,
    int total,
    int interest,
    int principal,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LedgerMoneyFormat.rupees(total),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _miniRow('Interest', interest),
          _miniRow('Principal', principal),
        ],
      ),
    );
  }

  Widget _miniRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(
            LedgerMoneyFormat.rupees(value),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
