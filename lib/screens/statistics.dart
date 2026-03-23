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

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _db = DatabaseService();
  Map<String, double> _stats = {};
  List<FuelLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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
    // Sort by key and take last 12
    final sorted = monthly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.length > 12) {
      return Map.fromEntries(sorted.sublist(sorted.length - 12));
    }
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final consumptionLogs = _logs.reversed.toList();
    final monthlyCosts = _getMonthlyCosts();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stat cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Ø Verbrauch',
                    value: '${(_stats['avg_consumption'] ?? 0).toStringAsFixed(1)} l/100km',
                    icon: Icons.local_gas_station,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    title: 'Ø Preis/L',
                    value: '${(_stats['avg_price'] ?? 0).toStringAsFixed(3)} €',
                    icon: Icons.price_change,
                  ),
                ),
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

            // Consumption chart
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
                              return FlSpot(e.key.toDouble(), e.value.consumption);
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

            // Monthly costs bar chart
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
        ),
      ),
    );
  }
}
