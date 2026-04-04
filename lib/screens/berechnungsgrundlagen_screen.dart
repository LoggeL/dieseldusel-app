import 'package:flutter/material.dart';

class BerechnungsgrundlagenScreen extends StatelessWidget {
  const BerechnungsgrundlagenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berechnungsgrundlagen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            icon: Icons.local_gas_station,
            iconColor: Colors.orange,
            title: 'Berechneter Verbrauch',
            children: [
              _FormulaBox(
                formula: 'Getankte Liter ÷ Trip-km × 100',
                codeStyle: codeStyle,
              ),
              const SizedBox(height: 8),
              _ExampleBox(
                example: '58,4 L ÷ 608,8 km × 100 = 9,59 l/100km',
                codeStyle: codeStyle,
              ),
              const SizedBox(height: 8),
              const Text(
                'Misst den Kraftstoff seit dem letzten Tankvorgang — inkl. Standheizung, Reserveverbräuche und sonstiger Verbräuche, die der Bordcomputer nicht erfasst.',
              ),
            ],
          ),
          _InfoCard(
            icon: Icons.speed,
            iconColor: Colors.blue,
            title: 'Bordcomputer-Verbrauch',
            children: [
              const Text(
                'Was der Tacho anzeigt — wird beim Tankvorgang manuell eingetragen.',
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Zeigt meist weniger an als der berechnete Wert — Messungenauigkeiten und Standheizung werden vom BC oft nicht vollständig erfasst.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _InfoCard(
            icon: Icons.trending_down,
            iconColor: Colors.green,
            title: 'Ø Verbrauch (gewichtet)',
            children: [
              _FormulaBox(
                formula: 'Summe aller Liter ÷ Summe aller Trip-km × 100',
                codeStyle: codeStyle,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'NICHT der einfache Mittelwert der Einzelwerte — gewichtet nach Fahrstrecke. Lange Fahrten haben mehr Einfluss als kurze.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _InfoCard(
            icon: Icons.computer,
            iconColor: Colors.cyan,
            title: 'Ø Bordcomputer',
            children: [
              const Text(
                'Arithmetischer Mittelwert aller BC-Einträge.',
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nur Einträge mit vorhandenem BC-Wert fließen ein.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _InfoCard(
            icon: Icons.calendar_month,
            iconColor: Colors.purple,
            title: 'Jährlicher / Monatlicher Verbrauch',
            children: [
              _FormulaBox(
                formula:
                    'Summe Liter (Zeitraum) ÷ Summe Trip-km (Zeitraum) × 100',
                codeStyle: codeStyle,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gleiche gewichtete Methode wie beim Gesamtschnitt — nicht der Mittelwert der Monatswerte, sondern direkt aus den Rohdaten berechnet.',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FormulaBox extends StatelessWidget {
  final String formula;
  final TextStyle? codeStyle;

  const _FormulaBox({required this.formula, this.codeStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(formula, style: codeStyle),
    );
  }
}

class _ExampleBox extends StatelessWidget {
  final String example;
  final TextStyle? codeStyle;

  const _ExampleBox({required this.example, this.codeStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bsp: ',
              style: TextStyle(color: Colors.green, fontSize: 12)),
          Expanded(
            child: Text(example,
                style: codeStyle?.copyWith(
                    color: Colors.green, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
