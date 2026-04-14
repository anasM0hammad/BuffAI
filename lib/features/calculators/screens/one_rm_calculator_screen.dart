import 'package:flutter/material.dart';

import '../widgets/calc_scaffold.dart';

/// Estimates 1RM from a completed set via Epley formula, and gives a reps
/// chart for common %1RM training intensities.
class OneRmCalculatorScreen extends StatefulWidget {
  const OneRmCalculatorScreen({super.key});

  @override
  State<OneRmCalculatorScreen> createState() => _OneRmCalculatorScreenState();
}

class _OneRmCalculatorScreenState extends State<OneRmCalculatorScreen> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();

  @override
  void initState() {
    super.initState();
    _weight.addListener(() => setState(() {}));
    _reps.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  double? get _oneRm {
    final w = double.tryParse(_weight.text.trim());
    final r = int.tryParse(_reps.text.trim());
    if (w == null || r == null || w <= 0 || r <= 0) return null;
    if (r == 1) return w;
    // Epley.
    return w * (1 + r / 30);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()} kg' : '${v.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final orm = _oneRm;
    return CalcScaffold(
      title: 'One Rep Max',
      children: [
        CalcField(
          label: 'Weight lifted',
          suffix: 'kg',
          controller: _weight,
        ),
        CalcField(
          label: 'Reps completed',
          suffix: 'reps',
          controller: _reps,
          allowDecimal: false,
        ),
        if (orm != null) ...[
          ResultCard(
            headline: 'ESTIMATED 1RM',
            rows: [
              ResultRow('1RM', _fmt(orm), emphasize: true),
            ],
            footnote:
                'Epley formula: w × (1 + reps/30). Accuracy drops above 10 '
                'reps — use a heavier set for a tighter estimate.',
          ),
          const SizedBox(height: 12),
          ResultCard(
            headline: 'TRAINING PERCENTAGES',
            rows: [
              ResultRow('95% — 1–2 reps (peak)', _fmt(orm * 0.95)),
              ResultRow('90% — 3 reps (strength)', _fmt(orm * 0.90)),
              ResultRow('85% — 5 reps (power)', _fmt(orm * 0.85)),
              ResultRow('80% — 6–8 reps (strength)', _fmt(orm * 0.80)),
              ResultRow('75% — 8–10 reps (hypertrophy)', _fmt(orm * 0.75)),
              ResultRow('70% — 10–12 reps (hypertrophy)', _fmt(orm * 0.70)),
              ResultRow('65% — 12–15 reps (volume)', _fmt(orm * 0.65)),
            ],
          ),
        ] else
          const ResultCard(
            headline: 'LOG A SET',
            rows: [ResultRow('', '—')],
          ),
      ],
    );
  }
}
