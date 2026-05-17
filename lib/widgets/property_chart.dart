import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/property_analytics_service.dart';
import '../utils/ledger_calculator.dart';

/// Interactive monthly collections chart for property / insights screens.
class PropertyCollectionsChart extends StatefulWidget {
  final Map<int, PropertyMonthBucket> buckets;
  final int year;
  final ValueChanged<int>? onYearChanged;
  final ValueChanged<int>? onMonthSelected;
  final int? selectedMonth;
  final Color barColor;

  const PropertyCollectionsChart({
    super.key,
    required this.buckets,
    required this.year,
    this.onYearChanged,
    this.onMonthSelected,
    this.selectedMonth,
    this.barColor = const Color(0xFF2563EB),
  });

  @override
  State<PropertyCollectionsChart> createState() => _PropertyCollectionsChartState();
}

class _PropertyCollectionsChartState extends State<PropertyCollectionsChart> {
  static const _labels = [
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

  String _axis(double v) {
    if (v <= 0) return '0';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).round()}k';
    return v.toInt().toString();
  }

  double _maxY() {
    var max = 0.0;
    for (var m = 1; m <= 12; m++) {
      max = [max, (widget.buckets[m]?.collected ?? 0).toDouble()]
          .reduce((a, b) => a > b ? a : b);
    }
    if (max <= 0) return 10000;
    final mag = max * 1.15;
    if (mag >= 100000) return ((mag / 50000).ceil() * 50000).toDouble();
    return ((mag / 1000).ceil() * 1000).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY();
    final interval = maxY / 4;
    final yearTotal = widget.buckets.values.fold<int>(
      0,
      (s, b) => s + b.collected,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Plot collections by month',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (widget.onYearChanged != null)
              DropdownButton<int>(
                value: widget.year,
                underline: const SizedBox.shrink(),
                items: List.generate(5, (i) {
                  final y = DateTime.now().year - i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (y) {
                  if (y != null) widget.onYearChanged!(y);
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.year} total: ${LedgerMoneyFormat.rupees(yearTotal)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
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
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (v, _) => Text(
                      _axis(v),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final m = v.toInt();
                      if (m < 1 || m > 12) return const SizedBox.shrink();
                      final sel = widget.selectedMonth == m;
                      return Text(
                        _labels[m],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel ? widget.barColor : Colors.grey.shade700,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(12, (i) {
                final m = i + 1;
                final val = (widget.buckets[m]?.collected ?? 0).toDouble();
                final sel = widget.selectedMonth == m;
                return BarChartGroupData(
                  x: m,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      width: 14,
                      color: widget.barColor.withValues(alpha: sel ? 1 : 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      borderSide: sel
                          ? BorderSide(color: widget.barColor, width: 2)
                          : BorderSide.none,
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (e, r) {
                  if (!e.isInterestedForInteractions ||
                      r?.spot == null ||
                      widget.onMonthSelected == null) {
                    return;
                  }
                  widget.onMonthSelected!(r!.spot!.touchedBarGroup.x);
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: const Color(0xFF1E3A8A),
                  getTooltipItem: (g, _, rod, __) {
                    final m = g.x;
                    final b = widget.buckets[m];
                    return BarTooltipItem(
                      '${_labels[m]}\n${LedgerMoneyFormat.rupees(b?.collected ?? 0)}\n'
                      '${b?.paymentCount ?? 0} payments',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
