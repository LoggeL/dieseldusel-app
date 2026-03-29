import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/updater.dart';
import '../services/database.dart';
import '../services/import_service.dart';
import '../models/fuel_log.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _db = DatabaseService();
  final _importService = const ImportService();

  static const _demoHeaders = [
    'Datum',
    'Gesamt-km',
    'Trip-km',
    'Liter',
    'Kosten',
    'EUR/Liter',
    'Verbrauch',
    'Notiz',
  ];

  static const _demoRow = [
    '2026-03-08',
    '155923',
    '768.6',
    '59.31',
    '119.75',
    '2.019',
    '7.3',
    'Shell Kaiserslautern',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('user_name') ?? '';
    _apiKeyCtrl.text = prefs.getString('openrouter_api_key') ?? '';
    _modelCtrl.text =
        prefs.getString('openrouter_model') ?? 'google/gemini-3-flash-preview';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text);
    await prefs.setString('openrouter_api_key', _apiKeyCtrl.text);
    await prefs.setString(
        'openrouter_model',
        _modelCtrl.text.trim().isEmpty
            ? 'google/gemini-3-flash-preview'
            : _modelCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final file = File(path);

    try {
      final result = await _importService.parseFile(file);
      if (result.logs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine gültigen Einträge gefunden')),
        );
        return;
      }

      for (final log in result.logs) {
        await _db.insertLog(log);
      }

      if (!mounted) return;
      final imported = result.logs.length;
      final skipped = result.skippedRows;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$imported Einträge importiert${skipped > 0 ? " ($skipped Zeilen übersprungen)" : ""}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $e')),
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
    _modelCtrl.dispose();
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
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'KI Modell',
              prefixIcon: Icon(Icons.smart_toy),
              border: OutlineInputBorder(),
              helperText: 'z.B. google/gemini-3-flash-preview',
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
            onPressed: _importData,
            icon: const Icon(Icons.upload_file),
            label: const Text('CSV/Excel importieren'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            label: const Text('Als CSV exportieren'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo-Tabelle für den Import',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CSV, XLS und XLSX werden importiert, wenn die Spalten dieser Struktur folgen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 52,
                      columns: _demoHeaders
                          .map((header) => DataColumn(label: Text(header)))
                          .toList(),
                      rows: [
                        DataRow(
                          cells: _demoRow
                              .map((value) => DataCell(Text(value)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                Text('DieselDusel',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Version 1.8.1',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Fahrtenbuch App',
                    style: Theme.of(context).textTheme.bodySmall),
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
