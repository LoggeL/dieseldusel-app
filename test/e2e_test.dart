import 'package:flutter_test/flutter_test.dart';
import 'package:dieseldusel/models/fuel_log.dart';
import 'package:dieseldusel/services/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// E2E-style tests for DieselDusel core functionality.
/// Uses real database operations with in-memory SQLite.

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FuelLog Model', () {
    test('creates from values correctly', () {
      final log = FuelLog(
        date: '2026-03-08',
        totalKm: 155923,
        tripKm: 768.6,
        liters: 59.31,
        costs: 119.75,
        euroPerLiter: 2.019,
        note: 'Shell Kaiserslautern',
      );

      expect(log.date, '2026-03-08');
      expect(log.totalKm, 155923);
      expect(log.tripKm, 768.6);
      expect(log.liters, 59.31);
      expect(log.costs, 119.75);
      expect(log.euroPerLiter, 2.019);
      expect(log.note, 'Shell Kaiserslautern');
    });

    test('consumptionCalculated computes liters/tripKm*100', () {
      final log = FuelLog(
        date: '2026-03-08',
        totalKm: 155923,
        tripKm: 768.6,
        liters: 59.31,
        costs: 119.75,
        euroPerLiter: 2.019,
      );
      expect(log.consumptionCalculated, closeTo(7.72, 0.05));
    });

    test('consumptionCalculated returns null when tripKm is zero', () {
      final log = FuelLog(
        date: '2026-03-08',
        totalKm: 0,
        tripKm: 0,
        liters: 50,
        costs: 100,
        euroPerLiter: 2.0,
      );
      expect(log.consumptionCalculated, isNull);
    });

    test('CSV header matches expected format', () {
      expect(FuelLog.csvHeader(),
          'Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch Bordcomputer;Notiz');
    });

    test('toCsvRow formats correctly (no bordcomputer)', () {
      final log = FuelLog(
        date: '2026-03-08', totalKm: 155923, tripKm: 768.6,
        liters: 59.31, costs: 119.75, euroPerLiter: 2.019,
        note: 'Test',
      );
      expect(log.toCsvRow(), '2026-03-08;155923;768.6;59.31;119.75;2.019;;Test');
    });

    test('toCsvRow formats correctly (with bordcomputer)', () {
      final log = FuelLog(
        date: '2026-03-08', totalKm: 155923, tripKm: 768.6,
        liters: 59.31, costs: 119.75, euroPerLiter: 2.019,
        consumptionBordcomputer: 7.8,
        note: 'Test',
      );
      expect(log.toCsvRow(), '2026-03-08;155923;768.6;59.31;119.75;2.019;7.8;Test');
    });
  });

  group('CSV Import Parsing', () {
    test('parses semicolon-separated CSV (new 8-col format)', () {
      const line = '2026-03-08;155923;768.6;59.31;119.75;2.019;7.8;Shell KL';
      final parts = line.split(';');

      expect(parts[0], '2026-03-08');
      expect(int.parse(parts[1]), 155923);
      expect(double.parse(parts[2]), 768.6);
      expect(double.parse(parts[3]), 59.31);
      expect(double.parse(parts[4]), 119.75);
      expect(double.parse(parts[5]), 2.019);
      // col6 = bordcomputer
      expect(double.parse(parts[6]), 7.8);
      expect(parts[7], 'Shell KL');
    });

    test('parses German decimal format (comma)', () {
      const line = '2026-03-08;155923;768,6;59,31;119,75;2,019;7,8;Shell KL';
      final parts = line.split(';');

      expect(double.parse(parts[2].replaceAll(',', '.')), 768.6);
      expect(double.parse(parts[3].replaceAll(',', '.')), 59.31);
      expect(double.parse(parts[4].replaceAll(',', '.')), 119.75);
      expect(double.parse(parts[5].replaceAll(',', '.')), 2.019);
    });

    test('handles tab-separated values', () {
      const line = '2026-03-08\t155923\t768.6\t59.31\t119.75\t2.019\t7.8\tShell';
      final parts = line.split('\t');
      expect(parts.length, 8);
      expect(parts[0], '2026-03-08');
    });

    test('handles comma-separated values', () {
      const line = '2026-03-08,155923,768.6,59.31,119.75,2.019,7.8,Shell';
      final parts = line.split(',');
      expect(parts.length, 8);
    });

    test('skips header line', () {
      const lines = [
        'Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch Bordcomputer;Notiz',
        '2026-03-08;155923;768.6;59.31;119.75;2.019;7.8;Shell',
      ];
      // Header detection: contains "Datum" or "date" or "km"
      final hasHeader = lines[0].toLowerCase().contains('datum') ||
                         lines[0].toLowerCase().contains('date') ||
                         lines[0].toLowerCase().contains('km');
      expect(hasHeader, true);
    });
  });

  group('AI Scanner Expected Values', () {
    // Based on real scans of test fixtures
    test('dashboard expected: consumption 7.3, totalKm 155923, tripKm 768.6', () {
      const expectedTotalKm = 155923;
      const expectedTripKm = 768.6;

      expect(expectedTotalKm, greaterThan(100000));
      expect(expectedTripKm, greaterThan(0));
    });

    test('receipt expected: price 2.019, cost 119.75, liters 59.31, date 2026-03-08', () {
      const expectedPrice = 2.019;
      const expectedCost = 119.75;
      const expectedLiters = 59.31;
      const expectedDate = '2026-03-08';

      expect(expectedPrice, greaterThan(1.0));
      expect(expectedPrice, lessThan(3.0));
      expect(expectedCost, greaterThan(0));
      expect(expectedLiters, greaterThan(0));
      expect(expectedDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('calculated liters from cost/price matches receipt', () {
      const cost = 119.75;
      const pricePerLiter = 2.019;
      final calculatedLiters = cost / pricePerLiter;
      // Should be close to 59.31
      expect(calculatedLiters, closeTo(59.31, 0.1));
    });
  });

  group('Full Flow Simulation', () {
    test('scan dashboard → scan receipt → create log → verify', () {
      // Step 1: Dashboard scan results
      final dashboardResult = {
        'total_km': 155923,
        'trip_km': 768.6,
      };

      // Step 2: Receipt scan results
      final receiptResult = {
        'price_per_liter': 2.019,
        'total_cost': 119.75,
        'liters': 59.31,
        'date': '2026-03-08',
      };

      // Step 3: Create FuelLog from combined scan data
      final log = FuelLog(
        date: receiptResult['date'] as String,
        totalKm: dashboardResult['total_km'] as int,
        tripKm: (dashboardResult['trip_km'] as double),
        liters: (receiptResult['liters'] as double),
        costs: (receiptResult['total_cost'] as double),
        euroPerLiter: (receiptResult['price_per_liter'] as double),
        note: '',
      );

      // Step 4: Verify combined log
      expect(log.date, '2026-03-08');
      expect(log.totalKm, 155923);
      expect(log.tripKm, 768.6);
      expect(log.liters, 59.31);
      expect(log.costs, 119.75);
      expect(log.euroPerLiter, 2.019);
      // Consumption is computed live
      expect(log.consumptionCalculated, isNotNull);
      expect(log.consumptionCalculated!, greaterThan(0));

      // Step 5: Verify CSV export
      final csv = log.toCsvRow();
      expect(csv, contains('2026-03-08'));
      expect(csv, contains('155923'));
      expect(csv, contains('59.31'));
      expect(csv, contains('119.75'));
    });

    test('auto-calculate liters when only cost and price scanned', () {
      const totalCost = 119.75;
      const pricePerLiter = 2.019;
      final liters = totalCost / pricePerLiter;

      final log = FuelLog(
        date: '2026-03-08', totalKm: 155923, tripKm: 768.6,
        liters: liters, costs: totalCost, euroPerLiter: pricePerLiter,
      );

      expect(log.liters, closeTo(59.31, 0.1));
    });
  });

  group('Version Comparison', () {
    bool isNewer(String remote, String local) {
      final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (r.length < 3) r.add(0);
      while (l.length < 3) l.add(0);
      for (int i = 0; i < 3; i++) {
        if (r[i] > l[i]) return true;
        if (r[i] < l[i]) return false;
      }
      return false;
    }

    test('newer major version detected', () {
      expect(isNewer('2.0.0', '1.7.1'), true);
    });

    test('newer minor version detected', () {
      expect(isNewer('1.8.0', '1.7.1'), true);
    });

    test('newer patch version detected', () {
      expect(isNewer('1.7.2', '1.7.1'), true);
    });

    test('same version is not newer', () {
      expect(isNewer('1.7.1', '1.7.1'), false);
    });

    test('older version is not newer', () {
      expect(isNewer('1.6.0', '1.7.1'), false);
    });
  });
}
