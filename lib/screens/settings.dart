import 'berechnungsgrundlagen_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
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

  bool _checkingUpdate = false;
  UpdateCheckResult? _lastUpdateResult;
  bool _saveScanImages = false;

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

  String _appVersion = '';

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() { _appVersion = info.version; });
  }

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('user_name') ?? '';
    _apiKeyCtrl.text = prefs.getString('openrouter_api_key') ?? '';
    _modelCtrl.text =
        prefs.getString('openrouter_model') ?? 'google/gemini-3-flash-preview';
    if (mounted) setState(() {
      _saveScanImages = prefs.getBool('save_scan_images') ?? false;
    });
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

  static const _storageChannel = MethodChannel('dieseldusel/storage');

  Future<void> _exportCsvToDownloads() async {
    final logs = await _db.getAllLogs();
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Einträge zum Exportieren')),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(FuelLog.csvHeader());
    for (final log in logs) {
      buffer.writeln(log.toCsvRow());
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final filename = 'dieseldusel_$timestamp.csv';

    try {
      final savedPath = await _storageChannel.invokeMethod<String>(
        'saveToDownloads',
        {'filename': filename, 'content': buffer.toString()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gespeichert: $savedPath'),
          duration: const Duration(seconds: 5),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: \${e.message}')),
      );
    }
  }


  Future<void> _exportJson() async {
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

    final jsonData = jsonEncode({
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'entries': logs.map((l) => l.toMap()).toList(),
    });

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dieseldusel_backup.json');
    await file.writeAsString(jsonData);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'DieselDusel Backup - $name',
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

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _lastUpdateResult = null;
    });

    final result = await AppUpdater.checkForUpdate();

    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _lastUpdateResult = result;
    });

    if (result.status == UpdateCheckStatus.updateAvailable &&
        result.update != null) {
      AppUpdater.showUpdateDialog(context, result.update!);
    }
  }

  Widget _buildUpdateStatusBadge() {
    final result = _lastUpdateResult;
    if (result == null) return const SizedBox.shrink();

    switch (result.status) {
      case UpdateCheckStatus.upToDate:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4CAF50), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
              const SizedBox(width: 6),
              Text(
                'App ist aktuell (${result.latestVersion ?? _appVersion})',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
              ),
            ],
          ),
        );
      case UpdateCheckStatus.updateAvailable:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                'Update ${result.latestVersion} verfügbar!',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        );
      case UpdateCheckStatus.networkError:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: Colors.red.shade300, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  result.errorMessage ?? 'Verbindungsfehler',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      case UpdateCheckStatus.noRelease:
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                result.errorMessage ?? 'Kein Release gefunden',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
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
          SwitchListTile(
            value: _saveScanImages,
            onChanged: (val) async {
              setState(() => _saveScanImages = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('save_scan_images', val);
            },
            title: const Text('Bilder zu Einträgen speichern'),
            subtitle: const Text('Scan-Fotos werden neben dem Eintrag gespeichert'),
            secondary: const Icon(Icons.photo_camera),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
            onPressed: _exportCsvToDownloads,
            icon: const Icon(Icons.download),
            label: const Text('Daten exportieren (CSV)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _importData,
            icon: const Icon(Icons.upload_file),
            label: const Text('Daten importieren'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportJson,
            icon: const Icon(Icons.backup),
            label: const Text('JSON-Backup erstellen'),
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
          // App info + Update section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_gas_station,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DieselDusel',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Fahrtenbuch App',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Version info table
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Installiert',
                                style: TextStyle(fontSize: 13)),
                            Text(
                              'v$_appVersion',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Aktuellste Version',
                                style: TextStyle(fontSize: 13)),
                            Text(
                              _lastUpdateResult?.latestVersion != null
                                  ? 'v${_lastUpdateResult!.latestVersion}'
                                  : '—',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkingUpdate ? null : _checkForUpdate,
                      icon: _checkingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.system_update, size: 18),
                      label: Text(_checkingUpdate
                          ? 'Prüfe Updates...'
                          : 'Nach Updates suchen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  _buildUpdateStatusBadge(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
