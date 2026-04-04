import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import 'lending_list_screen.dart';
import 'borrowing_list_screen.dart';
import '../../services/backup_service.dart';

class LedgerDashboard extends StatefulWidget {
  const LedgerDashboard({super.key});

  @override
  State<LedgerDashboard> createState() => _LedgerDashboardState();
}

class _LedgerDashboardState extends State<LedgerDashboard> {
  Map<int, double> monthlyData = {};
  bool loading = true;

  double totalCollection = 0;
  double totalLent = 0;
  double totalBorrowed = 0;

  @override
  void initState() {
    super.initState();
    loadMonthlyData();
  }

  Future<void> loadMonthlyData() async {
    Map<int, double> temp = {};
    double total = 0;
    double lent = 0;
    double borrowed = 0;

    var lendingSnap = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('lending')
        .get();

    for (var loan in lendingSnap.docs) {
      var loanData = loan.data();
      lent += (loanData['principal'] as num).toDouble();

      var instSnap = await loan.reference.collection('installments').get();

      for (var inst in instSnap.docs) {
        var data = inst.data();

        Timestamp ts = data['date'];
        DateTime d = ts.toDate();

        int month = d.month;
        double amount = (data['amount'] as num).toDouble();

        temp[month] = (temp[month] ?? 0) + amount;
        total += amount;
      }
    }

    var borrowSnap = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .get();

    for (var b in borrowSnap.docs) {
      var data = b.data();
      borrowed += (data['principal'] as num).toDouble();
    }

    setState(() {
      monthlyData = temp;
      totalCollection = total;
      totalLent = lent;
      totalBorrowed = borrowed;
      loading = false;
    });
  }

  List<FlSpot> getSpots() {
    List<FlSpot> spots = [];

    for (int i = 1; i <= 12; i++) {
      double val = monthlyData[i] ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return spots;
  }

  String monthName(int m) {
    const months = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return months[m];
  }

  Widget dashboardCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const SizedBox(height: 4),

              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          Icon(icon, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Ledger Dashboard")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            /// MODULE BUTTONS (TOP)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text("Lending"),

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LendingListScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text("Borrowing"),

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BorrowingListScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.backup),
                    label: Text("Backup"),
                    onPressed: () {
                      BackupService.exportLedgerBackup();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// OVERVIEW
            const Text(
              "Overview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),

              crossAxisCount: 4,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,

              children: [
                dashboardCard(
                  "Lent",
                  "₹ ${totalLent.toStringAsFixed(0)}",
                  Icons.arrow_upward,
                  Colors.blue,
                ),

                dashboardCard(
                  "Borrowed",
                  "₹ ${totalBorrowed.toStringAsFixed(0)}",
                  Icons.arrow_downward,
                  Colors.red,
                ),

                dashboardCard(
                  "Net",
                  "₹ ${(totalLent - totalBorrowed).toStringAsFixed(0)}",
                  Icons.balance,
                  Colors.teal,
                ),

                dashboardCard(
                  "Collected",
                  "₹ ${totalCollection.toStringAsFixed(0)}",
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              "Monthly Collection",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Container(
              height: 250,

              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),

              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),

                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int m = value.toInt();

                          if (m < 1 || m > 12) {
                            return const Text("");
                          }

                          return Text(
                            monthName(m),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),

                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),

                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),

                  borderData: FlBorderData(show: false),

                  lineBarsData: [
                    LineChartBarData(
                      spots: getSpots(),
                      isCurved: true,
                      color: const Color(0xFF1E3A8A),
                      barWidth: 3,
                      dotData: FlDotData(show: true),

                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF1E3A8A).withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
