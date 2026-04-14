import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/calc_scaffold.dart';

enum _Unit { kg, lb }

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  final _target = TextEditingController();
  _Unit _unit = _Unit.kg;
  double _bar = 20; // 20 kg / 45 lb

  // Standard gym plates (per side would use these).
  static const _kgPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
  static const _lbPlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

  @override
  void initState() {
    super.initState();
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  /// Greedy decomposition of per-side weight into available plates. Returns
  /// the plate breakdown plus any leftover weight we can't load.
  (Map<double, int> plates, double remaining) _solve(double perSide) {
    final plates = _unit == _Unit.kg ? _kgPlates : _lbPlates;
    final result = <double, int>{};
    double remaining = perSide;
    for (final p in plates) {
      // Allow a tiny epsilon for floating-point.
      while (remaining + 1e-6 >= p) {
        remaining -= p;
        result[p] = (result[p] ?? 0) + 1;
      }
    }
    return (result, remaining);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final unitLabel = _unit == _Unit.kg ? 'kg' : 'lb';
    final targetVal = double.tryParse(_target.text.trim());
    final showResult =
        targetVal != null && targetVal > 0 && targetVal >= _bar;

    final perSide = showResult ? (targetVal - _bar) / 2 : 0.0;
    final decomposition = showResult ? _solve(perSide) : null;

    return CalcScaffold(
      title: 'Plate Loader',
      children: [
        CalcSegment<_Unit>(
          label: 'Unit',
          options: const [_Unit.kg, _Unit.lb],
          display: (u) => u == _Unit.kg ? 'kg' : 'lb',
          value: _unit,
          onChanged: (v) => setState(() {
            _unit = v;
            _bar = v == _Unit.kg ? 20 : 45;
          }),
        ),
        CalcSegment<double>(
          label: 'Barbell',
          options: _unit == _Unit.kg
              ? const [15.0, 20.0]
              : const [35.0, 45.0],
          display: (w) => '${_fmt(w)} $unitLabel',
          value: _bar,
          onChanged: (v) => setState(() => _bar = v),
        ),
        CalcField(
          label: 'Target weight',
          suffix: unitLabel,
          controller: _target,
        ),
        if (!showResult)
          ResultCard(
            headline: 'ENTER TARGET',
            rows: [
              if (targetVal != null && targetVal < _bar)
                ResultRow('Target is under bar weight',
                    '${_fmt(_bar)} $unitLabel min')
              else
                const ResultRow('', '—'),
            ],
          )
        else ...[
          ResultCard(
            headline: 'LOAD PER SIDE',
            rows: [
              ResultRow('Bar', '${_fmt(_bar)} $unitLabel'),
              ResultRow('Plates total',
                  '${_fmt(targetVal - _bar)} $unitLabel'),
              ResultRow('Per side', '${_fmt(perSide)} $unitLabel',
                  emphasize: true),
            ],
          ),
          const SizedBox(height: 12),
          _PlateList(
            plates: decomposition!.$1,
            unit: unitLabel,
            remaining: decomposition.$2,
          ),
        ],
      ],
    );
  }
}

class _PlateList extends StatelessWidget {
  final Map<double, int> plates;
  final String unit;
  final double remaining;

  const _PlateList({
    required this.plates,
    required this.unit,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final entries = plates.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLATES',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'Bar only',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries
                  .map((e) => _PlateChip(
                        count: e.value,
                        weight: e.key,
                        unit: unit,
                      ))
                  .toList(),
            ),
          if (remaining > 0.01) ...[
            const SizedBox(height: 10),
            Text(
              'Can\'t be matched exactly — short by ${remaining.toStringAsFixed(2)} $unit per side.',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  final int count;
  final double weight;
  final String unit;

  const _PlateChip({
    required this.count,
    required this.weight,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = weight == weight.roundToDouble()
        ? weight.round().toString()
        : weight.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${count}×',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$fmt $unit',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
