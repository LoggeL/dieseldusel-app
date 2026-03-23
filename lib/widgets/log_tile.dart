import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fuel_log.dart';

class LogTile extends StatelessWidget {
  final FuelLog log;
  final VoidCallback? onTap;

  const LogTile({super.key, required this.log, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(log.date));
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.local_gas_station,
            color: Theme.of(context).colorScheme.primary),
      ),
      title: Text('$date — ${log.totalKm} km'),
      subtitle: Text(
        '${log.liters.toStringAsFixed(1)} L · '
        '${log.costs.toStringAsFixed(2)} € · '
        '${log.consumption.toStringAsFixed(1)} l/100km',
      ),
      trailing: log.note.isNotEmpty
          ? const Icon(Icons.note, size: 16)
          : null,
    );
  }
}
