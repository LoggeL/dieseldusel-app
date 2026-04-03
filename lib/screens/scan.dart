import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fuel_log.dart';
import '../services/ai_scanner.dart';
import '../utils/app_date.dart';
import 'manual_entry.dart';

enum ScanStep {
  chooseFirst,
  scanningFirst,
  chooseSecond,
  scanningSecond,
  review
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  ScanStep _step = ScanStep.chooseFirst;
  String? _error;

  // Scanned data
  double? _consumption, _tripKm, _pricePerLiter, _totalCost, _liters;
  int? _totalKm;
  String? _scanDate;
  String _firstType = ''; // 'dashboard' or 'receipt'
  String? _firstImagePath;
  String? _secondImagePath;

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  int? _toInt(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null) return null;
    return parsed.round();
  }

  bool _hasDashboardData({
    double? consumption,
    int? totalKm,
    double? tripKm,
  }) {
    return (consumption != null && consumption > 0) ||
        (totalKm != null && totalKm > 0) ||
        (tripKm != null && tripKm > 0);
  }

  bool _hasReceiptData({
    double? pricePerLiter,
    double? totalCost,
    double? liters,
    String? scanDate,
  }) {
    return (pricePerLiter != null && pricePerLiter > 0) ||
        (totalCost != null && totalCost > 0) ||
        (liters != null && liters > 0) ||
        scanDate != null;
  }

  Future<XFile?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1a2e1a),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(source: source);
  }

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openrouter_api_key');
  }

  Future<String> _getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openrouter_model') ??
        'google/gemini-3-flash-preview';
  }

  Future<void> _scanDashboard() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error =
          'Bitte zuerst den API-Key in den Einstellungen hinterlegen.');
      return;
    }
    final image = await _pickImage();
    if (image == null) return;
    final imagePath = image.path;

    setState(() {
      _step =
          _firstType.isEmpty ? ScanStep.scanningFirst : ScanStep.scanningSecond;
      _error = null;
    });

    try {
      final model = await _getModel();
      final scanner = AiScanner(apiKey: apiKey, model: model);
      final result = await scanner.scanDashboard(File(image.path));
      final consumption = _toDouble(result['consumption']);
      final totalKm = _toInt(result['total_km']);
      final tripKm = _toDouble(result['trip_km']);

      if (!_hasDashboardData(
        consumption: consumption,
        totalKm: totalKm,
        tripKm: tripKm,
      )) {
        throw Exception(
          'Keine verwertbaren Werte im Bild erkannt. Bitte ein klareres Foto vom Armaturenbrett versuchen.',
        );
      }

      setState(() {
        _consumption = consumption ?? _consumption;
        _totalKm = totalKm ?? _totalKm;
        _tripKm = tripKm ?? _tripKm;
        if (_firstType.isEmpty) {
          _firstType = 'dashboard';
          _firstImagePath = imagePath;
          _step = ScanStep.chooseSecond;
        } else {
          _secondImagePath = imagePath;
          _step = ScanStep.review;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Scan fehlgeschlagen: $e';
        _step =
            _firstType.isEmpty ? ScanStep.chooseFirst : ScanStep.chooseSecond;
      });
    }
  }

  Future<void> _scanReceipt() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error =
          'Bitte zuerst den API-Key in den Einstellungen hinterlegen.');
      return;
    }
    final image = await _pickImage();
    if (image == null) return;
    final imagePath = image.path;

    setState(() {
      _step =
          _firstType.isEmpty ? ScanStep.scanningFirst : ScanStep.scanningSecond;
      _error = null;
    });

    try {
      final model = await _getModel();
      final scanner = AiScanner(apiKey: apiKey, model: model);
      final result = await scanner.scanReceipt(File(image.path));
      final parsedDate = tryParseAppDate(result['date']?.toString());
      final pricePerLiter = _toDouble(result['price_per_liter']);
      final totalCost = _toDouble(result['total_cost']);
      final liters = _toDouble(result['liters']);
      final scanDate = parsedDate == null
          ? null
          : normalizeAppDate(result['date']?.toString());

      if (!_hasReceiptData(
        pricePerLiter: pricePerLiter,
        totalCost: totalCost,
        liters: liters,
        scanDate: scanDate,
      )) {
        throw Exception(
          'Keine verwertbaren Werte auf dem Kassenzettel erkannt. Bitte ein schaerferes Foto versuchen.',
        );
      }

      setState(() {
        _pricePerLiter = pricePerLiter ?? _pricePerLiter;
        _totalCost = totalCost ?? _totalCost;
        _liters = liters ?? _liters;
        _scanDate = scanDate ?? _scanDate;
        if (_firstType.isEmpty) {
          _firstType = 'receipt';
          _firstImagePath = imagePath;
          _step = ScanStep.chooseSecond;
        } else {
          _secondImagePath = imagePath;
          _step = ScanStep.review;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Scan fehlgeschlagen: $e';
        _step =
            _firstType.isEmpty ? ScanStep.chooseFirst : ScanStep.chooseSecond;
      });
    }
  }

  Future<void> _reviewAndSave() async {
    final log = FuelLog(
      date: _scanDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      totalKm: _totalKm ?? 0,
      tripKm: _tripKm ?? 0,
      liters: _liters ??
          (_totalCost != null && _pricePerLiter != null && _pricePerLiter! > 0
              ? _totalCost! / _pricePerLiter!
              : 0),
      costs: _totalCost ?? 0,
      euroPerLiter: _pricePerLiter ?? 0,
      consumption: _consumption ?? 0,
    );
    // Use the first scanned image (prefer dashboard/first)
    final sourceImage = _firstImagePath ?? _secondImagePath;
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ManualEntryScreen(existingLog: log, sourceImagePath: sourceImage)));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Eintrag gespeichert ✓')));
      // Pop back to main shell (home)
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _reset() {
    setState(() {
      _step = ScanStep.chooseFirst;
      _firstType = '';
      _consumption = null;
      _totalKm = null;
      _tripKm = null;
      _pricePerLiter = null;
      _totalCost = null;
      _liters = null;
      _scanDate = null;
      _firstImagePath = null;
      _secondImagePath = null;
      _error = null;
    });
  }

  void _skip() {
    setState(() => _step = ScanStep.review);
  }

  Widget _stepIndicator() {
    final steps = ['Scan 1', 'Scan 2', 'Prüfen'];
    final current =
        _step == ScanStep.chooseFirst || _step == ScanStep.scanningFirst
            ? 0
            : _step == ScanStep.chooseSecond || _step == ScanStep.scanningSecond
                ? 1
                : 2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
          3,
          (i) => Expanded(
                child: Column(children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i <= current
                          ? const Color(0xFF4CAF50)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i],
                      style: TextStyle(
                          fontSize: 10,
                          color: i <= current
                              ? const Color(0xFF4CAF50)
                              : Colors.white38)),
                ]),
              )),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white60)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isScanning =
        _step == ScanStep.scanningFirst || _step == ScanStep.scanningSecond;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto scannen'),
        actions: [
          if (_step != ScanStep.chooseFirst)
            IconButton(
                icon: const Icon(Icons.restart_alt),
                onPressed: _reset,
                tooltip: 'Neu starten'),
        ],
      ),
      body: isScanning
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF4CAF50)),
              SizedBox(height: 16),
              Text('KI analysiert Bild...',
                  style: TextStyle(color: Colors.white60)),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepIndicator(),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.red.withAlpha(30),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Step 1: Choose first scan
                    if (_step == ScanStep.chooseFirst) ...[
                      const Icon(Icons.camera_alt,
                          size: 48, color: Color(0xFF4CAF50)),
                      const SizedBox(height: 12),
                      const Text('Was möchtest du zuerst scannen?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Du kannst danach das andere scannen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 24),
                      _bigButton(Icons.speed, 'Armaturenbrett',
                          'Verbrauch, km-Stand, Trip', _scanDashboard),
                      const SizedBox(height: 12),
                      _bigButton(Icons.receipt_long, 'Kassenzettel',
                          'Preis, Liter, Datum', _scanReceipt),
                    ],

                    // Step 2: Choose second scan (show what was scanned, offer the other)
                    if (_step == ScanStep.chooseSecond) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF4CAF50).withAlpha(60)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF4CAF50), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                    '${_firstType == "dashboard" ? "Armaturenbrett" : "Kassenzettel"} gescannt ✓',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4CAF50))),
                              ]),
                              const SizedBox(height: 8),
                              if (_consumption != null)
                                _dataRow('Verbrauch',
                                    '${_consumption!.toStringAsFixed(1)} l/100km'),
                              if (_totalKm != null)
                                _dataRow('Gesamt-km', '$_totalKm'),
                              if (_tripKm != null)
                                _dataRow('Trip-km',
                                    '${_tripKm!.toStringAsFixed(1)}'),
                              if (_pricePerLiter != null)
                                _dataRow('Preis/Liter',
                                    '${_pricePerLiter!.toStringAsFixed(3)} €'),
                              if (_totalCost != null)
                                _dataRow('Gesamtkosten',
                                    '${_totalCost!.toStringAsFixed(2)} €'),
                              if (_liters != null)
                                _dataRow(
                                    'Liter', '${_liters!.toStringAsFixed(2)}'),
                              if (_scanDate != null)
                                _dataRow('Datum', _scanDate!),
                            ]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                          'Jetzt ${_firstType == "dashboard" ? "Kassenzettel" : "Armaturenbrett"} scannen:',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_firstType == 'dashboard')
                        _bigButton(Icons.receipt_long, 'Kassenzettel scannen',
                            'Preis, Liter, Datum', _scanReceipt)
                      else
                        _bigButton(Icons.speed, 'Armaturenbrett scannen',
                            'Verbrauch, km-Stand, Trip', _scanDashboard),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _skip,
                        child: const Text('Überspringen → direkt prüfen'),
                      ),
                    ],

                    // Step 3: Review
                    if (_step == ScanStep.review) ...[
                      const Text('Zusammenfassung',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(children: [
                          if (_consumption != null)
                            _dataRow('Verbrauch',
                                '${_consumption!.toStringAsFixed(1)} l/100km'),
                          if (_totalKm != null)
                            _dataRow('Gesamt-km', '$_totalKm'),
                          if (_tripKm != null)
                            _dataRow(
                                'Trip-km', '${_tripKm!.toStringAsFixed(1)}'),
                          if (_pricePerLiter != null)
                            _dataRow('Preis/Liter',
                                '${_pricePerLiter!.toStringAsFixed(3)} €'),
                          if (_totalCost != null)
                            _dataRow('Gesamtkosten',
                                '${_totalCost!.toStringAsFixed(2)} €'),
                          if (_liters != null)
                            _dataRow('Liter', '${_liters!.toStringAsFixed(2)}'),
                          if (_scanDate != null) _dataRow('Datum', _scanDate!),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _reviewAndSave,
                        icon: const Icon(Icons.edit),
                        label: const Text('Prüfen & Speichern'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ]),
            ),
    );
  }

  Widget _bigButton(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF1a2e1a),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(icon, size: 36, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                ])),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ]),
        ),
      ),
    );
  }
}
