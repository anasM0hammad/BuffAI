import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/calc_scaffold.dart';

enum _Activity {
  sedentary('Sedentary', 1.0),
  light('Light', 1.1),
  moderate('Moderate', 1.25),
  intense('Intense', 1.45);

  const _Activity(this.label, this.factor);
  final String label;
  final double factor;
}

enum _Weather {
  cool('Cool', 0.95),
  mild('Mild', 1.0),
  hot('Hot', 1.15),
  veryHot('Very hot', 1.3);

  const _Weather(this.label, this.factor);
  final String label;
  final double factor;
}

/// Daily water intake recommendation. Starts from a 35 ml/kg baseline and
/// scales by activity and weather. Height nudges the baseline slightly via
/// a body-surface-area approximation so taller users at the same weight get
/// a small bump.
class WaterCalculatorScreen extends StatefulWidget {
  const WaterCalculatorScreen({super.key});

  @override
  State<WaterCalculatorScreen> createState() => _WaterCalculatorScreenState();
}

class _WaterCalculatorScreenState extends State<WaterCalculatorScreen> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  _Activity _activity = _Activity.moderate;
  _Weather _weather = _Weather.mild;

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  double? _liters() {
    final w = double.tryParse(_weight.text);
    final h = double.tryParse(_height.text);
    if (w == null || w <= 0) return null;

    // Baseline: 35 ml per kg.
    var ml = w * 35;

    // Height nudge: scale by (height/170)^0.25 — small effect, ~+/-5%.
    if (h != null && h > 0) {
      final ratio = h / 170;
      ml *= 1 + (ratio - 1) * 0.25;
    }

    ml *= _activity.factor;
    ml *= _weather.factor;

    return ml / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final liters = _liters();
    final glasses = liters == null ? null : (liters * 1000 / 250).round();

    return CalcScaffold(
      title: 'Water Intake',
      children: [
        CalcField(
          label: 'Body weight',
          suffix: 'kg',
          controller: _weight,
        ),
        CalcField(
          label: 'Height (optional)',
          suffix: 'cm',
          controller: _height,
        ),
        CalcSegment<_Activity>(
          label: 'Activity',
          options: _Activity.values,
          display: (a) => a.label,
          value: _activity,
          onChanged: (a) => setState(() => _activity = a),
        ),
        CalcSegment<_Weather>(
          label: 'Weather',
          options: _Weather.values,
          display: (w) => w.label,
          value: _weather,
          onChanged: (w) => setState(() => _weather = w),
        ),
        if (liters != null) ...[
          ResultCard(
            headline: 'DAILY WATER',
            rows: [
              ResultRow(
                'Target',
                '${liters.toStringAsFixed(1)} L',
                emphasize: true,
              ),
              ResultRow('≈ Glasses (250 ml)', '$glasses'),
              ResultRow('≈ Bottles (500 ml)', '${(glasses! / 2).round()}'),
            ],
            footnote:
                'Sip steadily through the day. Add ~500 ml per hour of '
                'training on top, and more if you sweat heavily.',
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enter your body weight to see your target.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }
}
