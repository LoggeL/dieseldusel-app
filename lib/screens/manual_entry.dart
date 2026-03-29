import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fuel_log.dart';
import '../services/database.dart';

class ManualEntryScreen extends StatefulWidget {
  final FuelLog? existingLog;

  const ManualEntryScreen({super.key, this.existingLog});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late DateTime _date;
  final _totalKmCtrl = TextEditingController();
  final _tripKmCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _costsCtrl = TextEditingController();
  final _eurPerLiterCtrl = TextEditingController();
  final _consumptionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    if (log != null) {
      _date = DateTime.parse(log.date);
      _totalKmCtrl.text = log.totalKm.toString();
      _tripKmCtrl.text = log.tripKm.toString();
      _litersCtrl.text = log.liters.toString();
      _costsCtrl.text = log.costs.toString();
      _eurPerLiterCtrl.text = log.euroPerLiter.toString();
      _consumptionCtrl.text = log.consumption.toString();
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
    _consumptionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _autoCalculate() {
    final costs = double.tryParse(_costsCtrl.text);
    final eurPerLiter = double.tryParse(_eurPerLiterCtrl.text);
    final liters = double.tryParse(_litersCtrl.text);
    final tripKm = double.tryParse(_tripKmCtrl.text);

    // Auto-calc liters from costs and price
    if (costs != null && eurPerLiter != null && eurPerLiter > 0 && _litersCtrl.text.isEmpty) {
      _litersCtrl.text = (costs / eurPerLiter).toStringAsFixed(2);
    }

    // Auto-calc consumption from liters and trip
    final currentLiters = double.tryParse(_litersCtrl.text);
    if (currentLiters != null && tripKm != null && tripKm > 0 && _consumptionCtrl.text.isEmpty) {
      _consumptionCtrl.text = (currentLiters / tripKm * 100).toStringAsFixed(1);
    }

    // Auto-calc EUR/liter from costs and liters
    if (costs != null && currentLiters != null && currentLiters > 0 && _eurPerLiterCtrl.text.isEmpty) {
      _eurPerLiterCtrl.text = (costs / currentLiters).toStringAsFixed(3);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('de', 'DE'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Color(0xFF1B5E20),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _autoCalculate();

    final log = FuelLog(
      id: widget.existingLog?.id,
      date: DateFormat('yyyy-MM-dd').format(_date),
      totalKm: int.tryParse(_totalKmCtrl.text) ?? 0,
      tripKm: double.tryParse(_tripKmCtrl.text) ?? 0,
      liters: double.tryParse(_litersCtrl.text) ?? 0,
      costs: double.tryParse(_costsCtrl.text) ?? 0,
      euroPerLiter: double.tryParse(_eurPerLiterCtrl.text) ?? 0,
      consumption: double.tryParse(_consumptionCtrl.text) ?? 0,
      note: _noteCtrl.text,
    );

    if (widget.existingLog != null) {
      await _db.updateLog(log);
    } else {
      await _db.insertLog(log);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(_date);
    final isEditing = widget.existingLog != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Eintrag bearbeiten' : 'Neuer Eintrag'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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

            _buildField(_totalKmCtrl, 'Gesamt-km', Icons.speed, keyboard: TextInputType.number),
            _buildField(_tripKmCtrl, 'Trip-km', Icons.route, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _buildField(_litersCtrl, 'Liter', Icons.local_gas_station, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _buildField(_costsCtrl, 'Kosten (€)', Icons.euro, keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_eurPerLiterCtrl, 'EUR/Liter', Icons.price_change, keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _autoCalculate()),
            _buildField(_consumptionCtrl, 'Verbrauch (l/100km)', Icons.opacity, keyboard: const TextInputType.numberWithOptions(decimal: true)),
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
