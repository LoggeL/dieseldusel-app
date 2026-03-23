class FuelLog {
  final int? id;
  final String date;
  final int totalKm;
  final double tripKm;
  final double liters;
  final double costs;
  final double euroPerLiter;
  final double consumption;
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
    required this.consumption,
    this.note = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'total_km': totalKm,
      'trip_km': tripKm,
      'liters': liters,
      'costs': costs,
      'euro_per_liter': euroPerLiter,
      'consumption': consumption,
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
      consumption: (map['consumption'] as num).toDouble(),
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
    double? consumption,
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
      consumption: consumption ?? this.consumption,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  String toCsvRow() {
    return '$date;$totalKm;$tripKm;$liters;$costs;$euroPerLiter;$consumption;$note';
  }

  static String csvHeader() {
    return 'Datum;Gesamt-km;Trip-km;Liter;Kosten;EUR/Liter;Verbrauch;Notiz';
  }
}
