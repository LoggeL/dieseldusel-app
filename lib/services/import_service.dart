import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:excel2003/excel2003.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/fuel_log.dart';
import '../utils/app_date.dart';

class ImportParseResult {
  final List<FuelLog> logs;
  final int skippedRows;

  const ImportParseResult({
    required this.logs,
    required this.skippedRows,
  });
}

class ImportService {
  const ImportService();

  Future<ImportParseResult> parseFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    final bytes = await file.readAsBytes();

    switch (extension) {
      case '.csv':
      case '.txt':
        return _parseDelimitedText(utf8.decode(bytes, allowMalformed: true));
      case '.xlsx':
        return _parseXlsx(bytes);
      case '.xls':
        return _parseXls(bytes);
      default:
        throw UnsupportedError(
            'Dateiformat $extension wird nicht unterstützt.');
    }
  }

  ImportParseResult _parseDelimitedText(String content) {
    final lines = const LineSplitter()
        .convert(content.replaceFirst('\ufeff', ''))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    int skippedRows = 0;
    final logs = <FuelLog>[];

    for (final line in lines) {
      String separator = ';';
      if (!line.contains(';')) {
        separator = line.contains('\t') ? '\t' : ',';
      }

      final row = line.split(separator).map((part) => part.trim()).toList();
      final log = _buildLogFromRow(row);
      if (log == null) {
        skippedRows++;
        continue;
      }
      logs.add(log);
    }

    return ImportParseResult(logs: logs, skippedRows: skippedRows);
  }

  ImportParseResult _parseXlsx(Uint8List bytes) {
    final workbook = xlsx.Excel.decodeBytes(bytes);
    final rows = <List<Object?>>[];

    for (final tableName in workbook.tables.keys) {
      final sheet = workbook.tables[tableName];
      if (sheet == null) continue;
      for (final row in sheet.rows) {
        rows.add(
            row.map((cell) => _normalizeXlsxCellValue(cell?.value)).toList());
      }
    }

    return _parseSpreadsheetRows(rows);
  }

  ImportParseResult _parseXls(Uint8List bytes) {
    final reader = XlsReader.fromBytes(bytes);
    reader.open();

    final rows = <List<Object?>>[];
    for (int sheetIndex = 0;
        sheetIndex < reader.sheetNames.length;
        sheetIndex++) {
      final sheet = reader.sheet(sheetIndex);
      for (int rowIndex = sheet.firstRow;
          rowIndex < sheet.lastRow;
          rowIndex++) {
        final row = <Object?>[];
        for (int colIndex = sheet.firstCol;
            colIndex < sheet.lastCol;
            colIndex++) {
          row.add(sheet.cell(rowIndex, colIndex));
        }
        rows.add(row);
      }
    }

    return _parseSpreadsheetRows(rows);
  }

  ImportParseResult _parseSpreadsheetRows(List<List<Object?>> rows) {
    int skippedRows = 0;
    final logs = <FuelLog>[];

    for (final row in rows) {
      final log = _buildLogFromRow(row);
      if (log == null) {
        skippedRows++;
        continue;
      }
      logs.add(log);
    }

    return ImportParseResult(logs: logs, skippedRows: skippedRows);
  }

  FuelLog? _buildLogFromRow(List<Object?> row) {
    if (row.every((cell) => _stringifyCell(cell).trim().isEmpty)) return null;
    if (_looksLikeTitleRow(row) || _looksLikeHeaderRow(row)) return null;

    final normalizedDate =
        _extractNormalizedDate(row.isNotEmpty ? row[0] : null);
    if (normalizedDate == null) return null;

    // Spalten (neu, 8-spaltig): Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch Bordcomputer;Notiz
    // Alt 7-spaltig: col6 = berechneter Verbrauch (wird ignoriert/als BC übernommen), col7 = Notiz
    // Alt 9-spaltig: col6 = berechnet, col7 = BC, col8 = Notiz
    double? bordcomputer;
    String note;
    if (row.length >= 9) {
      // Altes 9-spaltiges Format mit berechneter Spalte
      bordcomputer = _parseNullableDoubleCell(_cellAt(row, 7));
      note = _stringifyCell(_cellAt(row, 8));
    } else if (row.length >= 8) {
      // Neues 8-spaltiges Format oder altes 8-spaltiges
      bordcomputer = _parseNullableDoubleCell(_cellAt(row, 6));
      note = _stringifyCell(_cellAt(row, 7));
    } else {
      // 7-spaltig: col6 als BC-Wert übernehmen
      bordcomputer = _parseNullableDoubleCell(_cellAt(row, 6));
      note = '';
    }
    return FuelLog(
      date: normalizedDate,
      totalKm: _parseIntCell(_cellAt(row, 1)),
      tripKm: _parseDoubleCell(_cellAt(row, 2)),
      liters: _parseDoubleCell(_cellAt(row, 3)),
      costs: _parseDoubleCell(_cellAt(row, 4)),
      euroPerLiter: _parseDoubleCell(_cellAt(row, 5)),
      consumptionBordcomputer: bordcomputer,
      note: note,
    );
  }

  Object? _normalizeXlsxCellValue(Object? value) {
    switch (value) {
      case null:
        return null;
      case xlsx.TextCellValue():
        return value.value;
      case xlsx.IntCellValue():
        return value.value;
      case xlsx.DoubleCellValue():
        return value.value;
      case xlsx.BoolCellValue():
        return value.value;
      case xlsx.DateCellValue():
        return DateTime(value.year, value.month, value.day);
      case xlsx.DateTimeCellValue():
        return DateTime(
          value.year,
          value.month,
          value.day,
          value.hour,
          value.minute,
          value.second,
          value.millisecond,
        );
      case xlsx.TimeCellValue():
        return '${value.hour}:${value.minute}:${value.second}';
      case xlsx.FormulaCellValue():
        return value.formula;
      default:
        return value.toString();
    }
  }

  Object? _cellAt(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return null;
    return row[index];
  }

  bool _looksLikeTitleRow(List<Object?> row) {
    final first = _stringifyCell(row.isNotEmpty ? row[0] : null).toLowerCase();
    return row.length == 1 && first.contains('fahrtenbuch');
  }

  bool _looksLikeHeaderRow(List<Object?> row) {
    final values =
        row.map((cell) => _stringifyCell(cell).toLowerCase()).toList();
    return values.any((value) => value.contains('datum')) &&
        values.any((value) => value.contains('km'));
  }

  String? _extractNormalizedDate(Object? value) {
    switch (value) {
      case null:
        return null;
      case DateTime():
        return DateFormat('yyyy-MM-dd').format(value);
      default:
        final raw = _stringifyCell(value);
        final parsed = tryParseAppDate(raw);
        if (parsed == null) return null;
        return normalizeAppDate(raw, fallback: parsed);
    }
  }

  int _parseIntCell(Object? value) {
    switch (value) {
      case int():
        return value;
      case double():
        return value.round();
      case num():
        return value.toInt();
      default:
        final normalized = _stringifyCell(value)
            .replaceAll('.', '')
            .replaceAll(',', '')
            .replaceAll(' ', '');
        return int.tryParse(normalized) ?? 0;
    }
  }

  double _parseDoubleCell(Object? value) {
    switch (value) {
      case int():
        return value.toDouble();
      case double():
        return value;
      case num():
        return value.toDouble();
      default:
        final normalized = _stringifyCell(value).replaceAll(',', '.');
        return double.tryParse(normalized) ?? 0;
    }
  }

  double? _parseNullableDoubleCell(Object? value) {
    if (value == null) return null;
    final str = _stringifyCell(value);
    if (str.isEmpty) return null;
    return double.tryParse(str.replaceAll(',', '.'));
  }

  String _stringifyCell(Object? value) {
    switch (value) {
      case null:
        return '';
      case DateTime():
        return DateFormat('yyyy-MM-dd').format(value);
      default:
        return value.toString().trim();
    }
  }
}
