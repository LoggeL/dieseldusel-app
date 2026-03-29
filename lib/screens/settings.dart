import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/updater.dart';
import '../services/database.dart';
import '../models/fuel_log.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('user_name') ?? '';
    _apiKeyCtrl.text = prefs.getString('openrouter_api_key') ?? '';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text);
    await prefs.setString('openrouter_api_key', _apiKeyCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    }
  }

  Future<void> _exportCsv() async {
    final logs = await _db.getAllLogs();
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Einträge zum Exportieren')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'DieselDusel';

    final buffer = StringBuffer();
    buffer.writeln('Fahrtenbuch - $name');
    buffer.writeln(FuelLog.csvHeader());
    for (final log in logs) {
      buffer.writeln(log.toCsvRow());
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fahrtenbuch_export.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Fahrtenbuch Export - $name',
    );
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Daten löschen?'),
        content: const Text(
          'Alle Fahrtenbuch-Einträge werden unwiderruflich gelöscht. '
          'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Alles löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle Daten gelöscht')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
              helperText: 'Wird beim CSV-Export verwendet',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'OpenRouter API Key',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
              helperText: 'Für die KI-Bilderkennung',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Einstellungen speichern'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            label: const Text('Als CSV exportieren'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Alle Daten löschen'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text('DieselDusel', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Version 1.2.1', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Fahrtenbuch App', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Suche nach Updates...')),
                    );
                    final update = await AppUpdater.checkForUpdate();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    if (update != null) {
                      AppUpdater.showUpdateDialog(context, update);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('App ist aktuell ✓')),
                      );
                    }
                  },
                  icon: const Icon(Icons.system_update, size: 18),
                  label: const Text('Nach Updates suchen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
