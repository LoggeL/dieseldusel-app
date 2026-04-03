import 'package:flutter_test/flutter_test.dart';
import 'package:dieseldusel/models/fuel_log.dart';

void main() {
  test('FuelLog serialization roundtrip', () {
    final log = FuelLog(
      date: '2026-03-23',
      totalKm: 50000,
      tripKm: 450.5,
      liters: 35.2,
      costs: 59.84,
      euroPerLiter: 1.699,
      note: 'Testfahrt',
    );

    final map = log.toMap();
    final restored = FuelLog.fromMap({...map, 'id': 1, 'created_at': '2026-03-23'});

    expect(restored.date, '2026-03-23');
    expect(restored.totalKm, 50000);
    expect(restored.tripKm, 450.5);
    expect(restored.liters, 35.2);
    expect(restored.costs, 59.84);
    expect(restored.euroPerLiter, 1.699);
    // consumption is now computed
    expect(restored.consumptionCalculated, closeTo(7.81, 0.05));
    expect(restored.note, 'Testfahrt');
  });

  test('FuelLog CSV export', () {
    final log = FuelLog(
      date: '2026-03-23',
      totalKm: 50000,
      tripKm: 450.5,
      liters: 35.2,
      costs: 59.84,
      euroPerLiter: 1.699,
      note: 'Test',
    );

    expect(log.toCsvRow(), '2026-03-23;50000;450.5;35.2;59.84;1.699;;Test');
    expect(FuelLog.csvHeader(), 'Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch Bordcomputer;Notiz');
  });

  test('FuelLog copyWith', () {
    final log = FuelLog(
      date: '2026-03-23',
      totalKm: 50000,
      tripKm: 450.5,
      liters: 35.2,
      costs: 59.84,
      euroPerLiter: 1.699,
    );

    final updated = log.copyWith(totalKm: 51000);
    expect(updated.totalKm, 51000);
    expect(updated.date, '2026-03-23');
  });
}
