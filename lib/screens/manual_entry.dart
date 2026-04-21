import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/fuel_log.dart';
import '../services/database.dart';
import '../utils/app_date.dart';
import '../services/image_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualEntryScreen extends StatefulWidget {
  final FuelLog? existingLog;
  final String? sourceImagePath;

  const ManualEntryScreen({super.key, this.existingLog, this.sourceImagePath});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  File? _existingImage;

  late DateTime _date;
  final _totalKmCtrl = TextEditingController();
  final _tripKmCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _costsCtrl = TextEditingController();
  final _eurPerLiterCtrl = TextEditingController();
  final _consumptionBcCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool get _isEditingPersistedLog => widget.existingLog?.id != null;

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    if (log != null) {
      _date = tryParseAppDate(log.date) ?? DateTime.now();
      if (log.id != null) {
        ImageStorageService().getImage(log.id!).then((f) {
          if (f != null && mounted) setState(() => _existingImage = f);
        });
      }
      _totalKmCtrl.text = log.totalKm.toString();
      _tripKmCtrl.text = log.tripKm.toString();
      _litersCtrl.text = log.liters.toString();
      _costsCtrl.text = log.costs.toString();
      _eurPerLiterCtrl.text = log.euroPerLiter.toString();
      _consumptionBcCtrl.text = log.consumptionBordcomputer?.toString() ?? '';
      _noteCtrl.text = log.note;
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _totalKmCtrl.dispose();
    _tripKmCtrl.dispose();
    _litersCtrl.dispose();
    _costsCtrl.dispose();
    _eurPerLiterCtrl.dispose();
    _consumptionBcCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _autoCalculate() {
    final costs = double.tryParse(_costsCtrl.text);
    final eurPerLiter = double.tryParse(_eurPerLiterCtrl.text);

    // Auto-calc liters from costs and price
    if (costs != null &&
        eurPerLiter != null &&
        eurPerLiter > 0 &&
        _litersCtrl.text.isEmpty) {
      _litersCtrl.text = (costs / eurPerLiter).toStringAsFixed(2);
    }

    // Auto-calc EUR/liter from costs and liters
    final currentLiters = double.tryParse(_litersCtrl.text);
    if (costs != null &&
        currentLiters != null &&
        currentLiters > 0 &&
        _eurPerLiterCtrl.text.isEmpty) {
      _eurPerLiterCtrl.text = (costs / currentLiters).toStringAsFixed(3);
    }
  }

  Future<void> _pickDate() async {
    DateTime tempDate = _date;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a2e1a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Abbrechen',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const Text('Datum wählen',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  TextButton(
                    onPressed: () {
                      setState(() => _date = tempDate);
                      Navigator.pop(ctx);
                    },
                    child: const Text('OK',
                        style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle:
                        TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
                  maximumDate: DateTime.now().add(const Duration(days: 1)),
                  minimumDate: DateTime(2000),
                  onDateTimeChanged: (d) => tempDate = d,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    _autoCalculate();
    if (!_formKey.currentState!.validate()) return;

    final log = FuelLog(
      id: _isEditingPersistedLog ? widget.existingLog?.id : null,
      date: DateFormat('yyyy-MM-dd').format(_date),
      totalKm: int.tryParse(_totalKmCtrl.text) ?? 0,
      tripKm: double.tryParse(_tripKmCtrl.text) ?? 0,
      liters: double.tryParse(_litersCtrl.text) ?? 0,
      costs: double.tryParse(_costsCtrl.text) ?? 0,
      euroPerLiter: double.tryParse(_eurPerLiterCtrl.text) ?? 0,
      consumptionBordcomputer: _consumptionBcCtrl.text.isNotEmpty
          ? double.tryParse(_consumptionBcCtrl.text)
          : null,
      note: _noteCtrl.text,
    );

    try {
      if (_isEditingPersistedLog) {
        await _db.updateLog(log);
      } else {
        final newId = await _db.insertLog(log);
        // Save scan image if setting is enabled
        if (widget.sourceImagePath != null) {
          final prefs = await SharedPreferences.getInstance();
          final saveImages = prefs.getBool('save_scan_images') ?? false;
          if (saveImages) {
            try {
              await ImageStorageService()
                  .saveImage(newId, widget.sourceImagePath!);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(_date);
    final isEditing = _isEditingPersistedLog;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Eintrag bearbeiten' : 'Neuer Eintrag'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scanned image preview
            if (_existingImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _existingImage!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Date picker
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Datum'),
              subtitle: Text(dateStr),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),

            _buildField(_totalKmCtrl, 'Gesamt-km', Icons.speed,
                keyboard: TextInputType.number),
            _buildField(_tripKmCtrl, 'Trip-km', Icons.route,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_litersCtrl, 'Liter', Icons.local_gas_station,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_costsCtrl, 'Kosten (€)', Icons.euro,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_eurPerLiterCtrl, 'EUR/Liter', Icons.price_change,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_consumptionBcCtrl, 'Verbrauch Bordcomputer (l/100km)', Icons.dashboard,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                required: false),
            _buildField(_noteCtrl, 'Notiz', Icons.note, required: false),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? 'Speichern' : 'Eintrag erstellen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Bitte ausfüllen' : null
            : null,
      ),
    );
  }
}
