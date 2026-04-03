import 'dart:io';
import 'package:flutter/material.dart';
import '../models/fuel_log.dart';
import '../services/image_storage_service.dart';
import '../utils/app_date.dart';

class LogTile extends StatefulWidget {
  final FuelLog log;
  final VoidCallback? onTap;

  const LogTile({super.key, required this.log, this.onTap});

  @override
  State<LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<LogTile> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.log.id == null) return;
    final file = await ImageStorageService().getImage(widget.log.id!);
    if (mounted) setState(() => _imageFile = file);
  }

  @override
  Widget build(BuildContext context) {
    final date = formatAppDate(widget.log.date);
    return ListTile(
      onTap: widget.onTap,
      leading: _imageFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _imageFile!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          : CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.local_gas_station,
                  color: Theme.of(context).colorScheme.primary),
            ),
      title: Text('$date — ${widget.log.totalKm} km'),
      subtitle: Text(
        '${widget.log.liters.toStringAsFixed(1)} L · '
        '${widget.log.costs.toStringAsFixed(2)} € · '
        '${widget.log.consumption.toStringAsFixed(1)} l/100km',
      ),
      trailing: widget.log.note.isNotEmpty ? const Icon(Icons.note, size: 16) : null,
    );
  }
}
