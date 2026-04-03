import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database.dart';
import '../models/fuel_log.dart';
import '../widgets/stat_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  Map<String, double> _stats = {};
  List<FuelLog> _logs = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stats = await _db.getStats();
    final logs = await _db.getAllLogs();
    if (mounted) {
      setState(() {
        _stats = stats;
        _logs = logs;
      });
    }
  }

  Map<String, double> _getMonthlyCosts() {
    final Map<String, double> monthly = {};
    for (final log in _logs) {
      final key = log.date.substring(0, 7); // YYYY-MM
      monthly[key] = (monthly[key] ?? 0) + log.costs;
    }
    final sorted = monthly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.length > 12) {
      return Map.fromEntries(sorted.sublist(sorted.length - 12));
    }
    return Map.fromEntries(sorted);
  }

  /// Returns monthly data: {YYYY-MM: {costs, km, liters, consumption_sum, fill_count}}
  Map<String, Map<String, double>> _getMonthlyData() {
    final Map<String, Map<String, double>> monthly = {};
    for (final log in _logs) {
      final key = log.date.substring(0, 7);
      monthly.putIfAbsent(key, () => {
        'costs': 0,
        'km': 0,
        'liters': 0,
        'consumption_sum': 0,
        'fill_count': 0,
      });
      monthly[key]!['costs'] = (monthly[key]!['costs']! + log.costs);
      monthly[key]!['km'] = (monthly[key]!['km']! + log.tripKm);
      monthly[key]!['liters'] = (monthly[key]!['liters']! + log.liters);
      final calc = log.consumptionCalculated;
      if (calc != null && calc > 0) {
        monthly[key]!['consumption_sum'] = (monthly[key]!['consumption_sum']! + calc);
        monthly[key]!['fill_count'] = (monthly[key]!['fill_count']! + 1);
      }
    }
    final sorted = monthly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sorted);
  }

  /// Returns yearly data
  Map<String, Map<String, double>> _getYearlyData() {
    final Map<String, Map<String, double>> yearly = {};
    for (final log in _logs) {
      final key = log.date.substring(0, 4);
      yearly.putIfAbsent(key, () => {
        'costs': 0,
        'km': 0,
        'liters': 0,
        'consumption_sum': 0,
        'fill_count': 0,
      });
      yearly[key]!['costs'] = (yearly[key]!['costs']! + log.costs);
      yearly[key]!['km'] = (yearly[key]!['km']! + log.tripKm);
      yearly[key]!['liters'] = (yearly[key]!['liters']! + log.liters);
      final calc = log.consumptionCalculated;
      if (calc != null && calc > 0) {
        yearly[key]!['consumption_sum'] = (yearly[key]!['consumption_sum']! + calc);
        yearly[key]!['fill_count'] = (yearly[key]!['fill_count']! + 1);
      }
    }
    final sorted = yearly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sorted);
  }

  String _monthLabel(String key) {
    // key = YYYY-MM
    const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${months[m - 1]}\n${parts[0].substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gesamt'),
            Tab(text: 'Monatlich'),
            Tab(text: 'Jährlich'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverallTab(),
            _buildMonthlyTab(),
            _buildYearlyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallTab() {
    final consumptionLogs = _logs.reversed.toList();
    final monthlyCosts = _getMonthlyCosts();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Ø Verbrauch (berechnet)',
                value: '${(_stats['avg_consumption'] ?? 0).toStringAsFixed(1)} l/100km',
                icon: Icons.opacity,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'Ø Verbrauch (BC)',
                value: (_stats['avg_consumption_bc'] ?? 0) > 0
                    ? '${(_stats['avg_consumption_bc'] ?? 0).toStringAsFixed(1)} l/100km'
                    : '—',
                icon: Icons.dashboard,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Ø Preis/L',
                value: '${(_stats['avg_price'] ?? 0).toStringAsFixed(3)} €',
                icon: Icons.price_change,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Gesamtkosten',
                value: '${(_stats['total_costs'] ?? 0).toStringAsFixed(2)} €',
                icon: Icons.euro,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'Gesamtliter',
                value: '${(_stats['total_liters'] ?? 0).toStringAsFixed(1)} L',
                icon: Icons.opacity,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatCard(
          title: 'Gesamtkilometer',
          value: '${(_stats['total_km'] ?? 0).toStringAsFixed(0)} km',
          icon: Icons.speed,
        ),
        const SizedBox(height: 24),

        if (consumptionLogs.length >= 2) ...[
          Text('Verbrauch über Zeit', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: consumptionLogs.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.consumptionCalculated ?? 0);
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFF4CAF50),
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (monthlyCosts.length >= 2) ...[
          Text('Monatliche Kosten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= monthlyCosts.length) {
                              return const SizedBox.shrink();
                            }
                            final key = monthlyCosts.keys.elementAt(idx);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(key.substring(5), style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: monthlyCosts.entries.toList().asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.value,
                            color: const Color(0xFF4CAF50),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],

        if (_logs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Noch keine Daten vorhanden',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthlyTab() {
    final monthlyData = _getMonthlyData();
    if (monthlyData.isEmpty) {
      return const Center(child: Text('Noch keine Daten vorhanden'));
    }

    // Show last 12 months
    final entries = monthlyData.entries.toList();
    final displayEntries = entries.length > 12
        ? entries.sublist(entries.length - 12)
        : entries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Consumption chart
        Text('Ø Verbrauch pro Monat', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (displayEntries.length >= 2) ...[
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= displayEntries.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _monthLabel(displayEntries[idx].key),
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: displayEntries.asMap().entries.map((e) {
                      final d = e.value.value;
                      final fillCount = d['fill_count']!;
                      final avgConsumption = fillCount > 0 ? d['consumption_sum']! / fillCount : 0.0;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: avgConsumption,
                            color: const Color(0xFF4CAF50),
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Monthly table
        Text('Monatsübersicht', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header
                Row(
                  children: const [
                    Expanded(flex: 2, child: Text('Monat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('Ø l/100km', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('Kosten', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('km', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  ],
                ),
                const Divider(),
                ...displayEntries.reversed.map((entry) {
                  final key = entry.key;
                  final d = entry.value;
                  final fillCount = d['fill_count']!;
                  final avgConsumption = fillCount > 0 ? d['consumption_sum']! / fillCount : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(key, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text(
                          avgConsumption > 0 ? avgConsumption.toStringAsFixed(1) : '—',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        )),
                        Expanded(flex: 2, child: Text(
                          '${d['costs']!.toStringAsFixed(2)} €',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        )),
                        Expanded(flex: 2, child: Text(
                          '${d['km']!.toStringAsFixed(0)} km',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        )),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyTab() {
    final yearlyData = _getYearlyData();
    if (yearlyData.isEmpty) {
      return const Center(child: Text('Noch keine Daten vorhanden'));
    }

    final entries = yearlyData.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Yearly costs bar chart
        if (entries.length >= 1) ...[
          Text('Kosten pro Jahr', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= entries.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(entries[idx].key, style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: entries.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.value['costs']!,
                            color: const Color(0xFF2196F3),
                            width: 28,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        Text('Jahresübersicht', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...entries.reversed.map((entry) {
          final year = entry.key;
          final d = entry.value;
          final fillCount = d['fill_count']!;
          final avgConsumption = fillCount > 0 ? d['consumption_sum']! / fillCount : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(year, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _yearStat(context, 'Gesamtkosten', '${d['costs']!.toStringAsFixed(2)} €', Icons.euro),
                      _yearStat(context, 'Kilometer', '${d['km']!.toStringAsFixed(0)} km', Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _yearStat(context, 'Tankvolumen', '${d['liters']!.toStringAsFixed(1)} L', Icons.opacity),
                      _yearStat(context, 'Ø Verbrauch', avgConsumption > 0 ? '${avgConsumption.toStringAsFixed(1)} l/100km' : '—', Icons.local_gas_station),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _yearStat(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
