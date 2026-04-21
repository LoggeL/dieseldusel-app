class FuelLog {
  final int? id;
  final String date;
  final int totalKm;
  final double tripKm;
  final double liters;
  final double costs;
  final double euroPerLiter;
  final double? consumptionBordcomputer; // vom Bordcomputer abgelesen
  final String note;
  final String? createdAt;

  FuelLog({
    this.id,
    required this.date,
    required this.totalKm,
    required this.tripKm,
    required this.liters,
    required this.costs,
    required this.euroPerLiter,
    this.consumptionBordcomputer,
    this.note = '',
    this.createdAt,
  });

  /// Live berechneter Verbrauch: Liter / Trip-km * 100
  double? get consumptionCalculated =>
      (liters > 0 && tripKm > 0) ? liters / tripKm * 100 : null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'total_km': totalKm,
      'trip_km': tripKm,
      'liters': liters,
      'costs': costs,
      'euro_per_liter': euroPerLiter,
      'consumption_bordcomputer': consumptionBordcomputer,
      'note': note,
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      totalKm: map['total_km'] as int,
      tripKm: (map['trip_km'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      costs: (map['costs'] as num).toDouble(),
      euroPerLiter: (map['euro_per_liter'] as num).toDouble(),
      consumptionBordcomputer: map['consumption_bordcomputer'] != null
          ? (map['consumption_bordcomputer'] as num).toDouble()
          : null,
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  FuelLog copyWith({
    int? id,
    String? date,
    int? totalKm,
    double? tripKm,
    double? liters,
    double? costs,
    double? euroPerLiter,
    double? consumptionBordcomputer,
    bool clearConsumptionBordcomputer = false,
    String? note,
  }) {
    return FuelLog(
      id: id ?? this.id,
      date: date ?? this.date,
      totalKm: totalKm ?? this.totalKm,
      tripKm: tripKm ?? this.tripKm,
      liters: liters ?? this.liters,
      costs: costs ?? this.costs,
      euroPerLiter: euroPerLiter ?? this.euroPerLiter,
      consumptionBordcomputer: clearConsumptionBordcomputer
          ? null
          : consumptionBordcomputer ?? this.consumptionBordcomputer,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  String toCsvRow() {
    // Sanitize note: the importer splits on ; literally, so strip delimiters
    // and line breaks that would otherwise corrupt re-imports.
    final safeNote = note.replaceAll(RegExp(r'[;\r\n]+'), ' ').trim();
    return '$date;$totalKm;$tripKm;$liters;$costs;$euroPerLiter;${consumptionBordcomputer ?? ''};$safeNote';
  }

  static String csvHeader() {
    return 'Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch Bordcomputer;Notiz';
  }
}
