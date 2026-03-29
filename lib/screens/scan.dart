import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_scanner.dart';
import 'manual_entry.dart';
import '../models/fuel_log.dart';
import 'package:intl/intl.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  // Collected data from scans
  double? _consumption;
  int? _totalKm;
  double? _tripKm;
  double? _pricePerLiter;
  double? _totalCost;
  double? _liters;
  String? _scanDate;

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openrouter_api_key');
  }


  Future<XFile?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Kamera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(source: source);
  }

  Future<void> _scanDashboard() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error = 'Bitte zuerst den API-Key in den Einstellungen hinterlegen.');
      return;
    }

    final image = await _pickImage();
    if (image == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString("openrouter_model") ?? "google/gemini-3-flash-preview";
      final scanner = AiScanner(apiKey: apiKey, model: model);
      final result = await scanner.scanDashboard(File(image.path));
      setState(() {
        if (result['consumption'] != null) _consumption = (result['consumption'] as num).toDouble();
        if (result['total_km'] != null) _totalKm = (result['total_km'] as num).toInt();
        if (result['trip_km'] != null) _tripKm = (result['trip_km'] as num).toDouble();
      });
    } catch (e) {
      setState(() => _error = 'Scan fehlgeschlagen: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scanReceipt() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error = 'Bitte zuerst den API-Key in den Einstellungen hinterlegen.');
      return;
    }

    final image = await _pickImage();
    if (image == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs2 = await SharedPreferences.getInstance();
      final model2 = prefs2.getString("openrouter_model") ?? "google/gemini-3-flash-preview";
      final scanner = AiScanner(apiKey: apiKey, model: model2);
      final result = await scanner.scanReceipt(File(image.path));
      setState(() {
        if (result['price_per_liter'] != null) _pricePerLiter = (result['price_per_liter'] as num).toDouble();
        if (result['total_cost'] != null) _totalCost = (result['total_cost'] as num).toDouble();
        if (result['liters'] != null) _liters = (result['liters'] as num).toDouble();
        if (result['date'] != null) _scanDate = result['date'] as String;
      });
    } catch (e) {
      setState(() => _error = 'Scan fehlgeschlagen: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _reviewAndSave() {
    final log = FuelLog(
      date: _scanDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      totalKm: _totalKm ?? 0,
      tripKm: _tripKm ?? 0,
      liters: _liters ?? (_totalCost != null && _pricePerLiter != null && _pricePerLiter! > 0
          ? _totalCost! / _pricePerLiter!
          : 0),
      costs: _totalCost ?? 0,
      euroPerLiter: _pricePerLiter ?? 0,
      consumption: _consumption ?? 0,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ManualEntryScreen(existingLog: log)),
    );
  }

  bool get _hasAnyData =>
      _consumption != null ||
      _totalKm != null ||
      _tripKm != null ||
      _pricePerLiter != null ||
      _totalCost != null ||
      _liters != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto scannen')),
      body: _loading
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('AI analysiert das Foto...'),
              ],
            ))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )),
                    ),
                  ),
                const SizedBox(height: 8),

                // Scan buttons
                FilledButton.icon(
                  onPressed: _scanDashboard,
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Armaturenbrett scannen'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _scanReceipt,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Tankquittung scannen'),
                ),
                const SizedBox(height: 24),

                // Scanned data preview
                if (_hasAnyData) ...[
                  Text('Erkannte Daten', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_totalKm != null) _dataRow('Gesamt-km', '$_totalKm km'),
                          if (_tripKm != null) _dataRow('Trip-km', '${_tripKm!.toStringAsFixed(1)} km'),
                          if (_consumption != null) _dataRow('Verbrauch', '${_consumption!.toStringAsFixed(1)} l/100km'),
                          if (_pricePerLiter != null) _dataRow('EUR/Liter', '${_pricePerLiter!.toStringAsFixed(3)} €'),
                          if (_totalCost != null) _dataRow('Gesamtkosten', '${_totalCost!.toStringAsFixed(2)} €'),
                          if (_liters != null) _dataRow('Liter', '${_liters!.toStringAsFixed(2)} L'),
                          if (_scanDate != null) _dataRow('Datum', _scanDate!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reviewAndSave,
                    icon: const Icon(Icons.edit),
                    label: const Text('Prüfen & Speichern'),
                  ),
                ],

                if (!_hasAnyData && _error == null) ...[
                  const SizedBox(height: 32),
                  Icon(Icons.camera_alt, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Fotografiere dein Armaturenbrett oder deine Tankquittung,\n'
                    'um die Daten automatisch zu erkennen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
