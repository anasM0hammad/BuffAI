import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../widgets/calc_scaffold.dart';

enum _Sex { male, female }

/// US Navy method (log10 based). Inputs in centimeters.
class BodyFatCalculatorScreen extends ConsumerStatefulWidget {
  const BodyFatCalculatorScreen({super.key});

  @override
  ConsumerState<BodyFatCalculatorScreen> createState() =>
      _BodyFatCalculatorScreenState();
}

class _BodyFatCalculatorScreenState
    extends ConsumerState<BodyFatCalculatorScreen> {
  final _height = TextEditingController();
  final _neck = TextEditingController();
  final _waist = TextEditingController();
  final _hip = TextEditingController();

  _Sex _sex = _Sex.male;
  bool _sexTouchedByUser = false;

  @override
  void initState() {
    super.initState();
    _height.addListener(() => setState(() {}));
    _neck.addListener(() => setState(() {}));
    _waist.addListener(() => setState(() {}));
    _hip.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _height.dispose();
    _neck.dispose();
    _waist.dispose();
    _hip.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserProfile p) {
    if (_height.text.isEmpty && p.heightCm != null) {
      _height.text = _fmtNum(p.heightCm!);
    }
    if (!_sexTouchedByUser && p.gender != Gender.unspecified) {
      final newSex = p.gender == Gender.male ? _Sex.male : _Sex.female;
      if (_sex != newSex) setState(() => _sex = newSex);
    }
  }

  double? _calc() {
    final h = double.tryParse(_height.text.trim());
    final n = double.tryParse(_neck.text.trim());
    final w = double.tryParse(_waist.text.trim());
    if (h == null || n == null || w == null) return null;
    if (h <= 0 || n <= 0 || w <= 0) return null;

    if (_sex == _Sex.male) {
      final val = w - n;
      if (val <= 0) return null;
      return 495 /
              (1.0324 -
                  0.19077 * (_log10(val)) +
                  0.15456 * _log10(h)) -
          450;
    } else {
      final hip = double.tryParse(_hip.text.trim());
      if (hip == null || hip <= 0) return null;
      final val = w + hip - n;
      if (val <= 0) return null;
      return 495 /
              (1.29579 -
                  0.35004 * _log10(val) +
                  0.22100 * _log10(h)) -
          450;
    }
  }

  double _log10(double x) => math.log(x) / math.ln10;

  String _category(double bf) {
    if (_sex == _Sex.male) {
      if (bf < 6) return 'Essential / stage lean';
      if (bf < 14) return 'Athlete / lean';
      if (bf < 18) return 'Fitness';
      if (bf < 25) return 'Average';
      return 'Above average';
    } else {
      if (bf < 14) return 'Essential / stage lean';
      if (bf < 21) return 'Athlete / lean';
      if (bf < 25) return 'Fitness';
      if (bf < 32) return 'Average';
      return 'Above average';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserProfile>(
      userProfileProvider,
      (_, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _seedFromProfile(next);
        });
      },
      fireImmediately: true,
    );

    final result = _calc();
    return CalcScaffold(
      title: 'Body Fat %',
      children: [
        CalcSegment<_Sex>(
          label: 'Sex',
          options: const [_Sex.male, _Sex.female],
          display: (s) => s == _Sex.male ? 'Male' : 'Female',
          value: _sex,
          onChanged: (v) => setState(() {
            _sex = v;
            _sexTouchedByUser = true;
          }),
        ),
        CalcField(label: 'Height', suffix: 'cm', controller: _height),
        CalcField(
            label: 'Neck circumference', suffix: 'cm', controller: _neck),
        CalcField(
            label: 'Waist circumference (at navel)',
            suffix: 'cm',
            controller: _waist),
        if (_sex == _Sex.female)
          CalcField(
              label: 'Hip circumference (widest)',
              suffix: 'cm',
              controller: _hip),
        if (result != null)
          ResultCard(
            headline: 'ESTIMATED BODY FAT',
            rows: [
              ResultRow(
                'Body Fat %',
                '${result.toStringAsFixed(1)}%',
                emphasize: true,
              ),
              ResultRow('Category', _category(result)),
            ],
            footnote:
                'Measurements: neck below the Adam\'s apple, waist at the '
                'navel (male) or narrowest point (female), hip at the widest '
                'point. Accuracy ±3%. Use a cloth tape, no compression.',
          )
        else
          const ResultCard(
            headline: 'FILL YOUR MEASUREMENTS',
            rows: [ResultRow('', '—')],
          ),
      ],
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
