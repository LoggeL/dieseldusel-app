import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database.dart';
import '../models/fuel_log.dart';
import '../widgets/stat_card.dart';
import '../services/updater.dart';
import 'manual_entry.dart';
import 'scan.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  Map<String, double> _stats = {};
  FuelLog? _lastLog;
  List<FuelLog> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final update = await AppUpdater.checkForUpdate();
    if (update != null && mounted) {
      AppUpdater.showUpdateDialog(context, update);
    }
  }

  Future<void> _loadData() async {
    final stats = await _db.getStats();
    final lastLog = await _db.getLastLog();
    final allLogs = await _db.getAllLogs();
    final recent = allLogs.length > 10 ? allLogs.sublist(0, 10) : allLogs;
    if (mounted) {
      setState(() {
        _stats = stats;
        _lastLog = lastLog;
        _recentLogs = recent.reversed.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DieselDusel')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats cards
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
                    title: 'Gesamt-km',
                    value: '${(_stats['total_km'] ?? 0).toStringAsFixed(0)} km',
                    icon: Icons.speed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatCard(
              title: 'Durchschnittsverbrauch',
              value: '${(_stats['avg_consumption'] ?? 0).toStringAsFixed(1)} l/100km',
              icon: Icons.local_gas_station,
            ),
            const SizedBox(height: 16),

            // Last entry preview
            if (_lastLog != null) ...[
              Text('Letzter Eintrag', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_lastLog!.date} — ${_lastLog!.totalKm} km'),
                      Text(
                        '${_lastLog!.liters.toStringAsFixed(1)} L · '
                        '${_lastLog!.costs.toStringAsFixed(2)} € · '
                        '${_lastLog!.consumption.toStringAsFixed(1)} l/100km',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Chart
            if (_recentLogs.length >= 2) ...[
              Text('Verbrauch über Zeit', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
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
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _recentLogs.asMap().entries.map((e) {
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
              const SizedBox(height: 16),
            ],

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Neuer Eintrag'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto scannen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
