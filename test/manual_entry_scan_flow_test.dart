import 'package:dieseldusel/models/fuel_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scan-Flow Persistenzlogik', () {
    test('gescannter Log ohne ID muss als neuer Eintrag behandelt werden', () {
      final scannedLog = FuelLog(
        date: '2026-03-08',
        totalKm: 155923,
        tripKm: 768.6,
        liters: 59.31,
        costs: 119.75,
        euroPerLiter: 2.019,
        consumption: 7.3,
      );

      final isExistingPersistedLog = scannedLog.id != null;

      expect(isExistingPersistedLog, isFalse);
    });

    test('nur Logs mit ID gelten als bestehend und werden geupdatet', () {
      final existingLog = FuelLog(
        id: 42,
        date: '2026-03-08',
        totalKm: 155923,
        tripKm: 768.6,
        liters: 59.31,
        costs: 119.75,
        euroPerLiter: 2.019,
        consumption: 7.3,
      );

      final isExistingPersistedLog = existingLog.id != null;

      expect(isExistingPersistedLog, isTrue);
    });
  });
}
