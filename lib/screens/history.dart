import 'package:flutter/material.dart';
import '../services/database.dart';
import '../models/fuel_log.dart';
import '../widgets/log_tile.dart';
import 'manual_entry.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  List<FuelLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _db.getAllLogs();
    if (mounted) setState(() => _logs = logs);
  }

  Future<void> _deleteLog(FuelLog log) async {
    await _db.deleteLog(log.id!);
    _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eintrag gelöscht')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fahrtenbuch')),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: _logs.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_gas_station, size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('Noch keine Einträge',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Dismissible(
                    key: ValueKey(log.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Theme.of(context).colorScheme.error,
                      child: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.onError),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eintrag löschen?'),
                          content: const Text('Dieser Eintrag wird unwiderruflich gelöscht.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Abbrechen'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Löschen'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) => _deleteLog(log),
                    child: LogTile(
                      log: log,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManualEntryScreen(existingLog: log),
                          ),
                        );
                        _loadLogs();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
