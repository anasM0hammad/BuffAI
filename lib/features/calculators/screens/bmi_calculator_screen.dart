import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../widgets/calc_scaffold.dart';

class BmiCalculatorScreen extends ConsumerStatefulWidget {
  const BmiCalculatorScreen({super.key});

  @override
  ConsumerState<BmiCalculatorScreen> createState() =>
      _BmiCalculatorScreenState();
}

class _BmiCalculatorScreenState extends ConsumerState<BmiCalculatorScreen> {
  final _weight = TextEditingController();
  final _height = TextEditingController();

  @override
  void initState() {
    super.initState();
    _weight.addListener(() => setState(() {}));
    _height.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserProfile p) {
    if (_weight.text.isEmpty && p.weightKg != null) {
      _weight.text = _fmtNum(p.weightKg!);
    }
    if (_height.text.isEmpty && p.heightCm != null) {
      _height.text = _fmtNum(p.heightCm!);
    }
  }

  double? get _bmi {
    final w = double.tryParse(_weight.text.trim());
    final h = double.tryParse(_height.text.trim());
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  (String, String) _category(double bmi) {
    if (bmi < 18.5) return ('Underweight', 'Eat more. Lift more.');
    if (bmi < 25) return ('Healthy range', 'Solid baseline. Train hard.');
    if (bmi < 30) return ('Overweight', 'Gentle deficit + strength work.');
    if (bmi < 35) return ('Obese I', 'Steady deficit + daily walking.');
    if (bmi < 40) return ('Obese II', 'Structured plan + medical support.');
    return ('Obese III', 'Strongly consider medical guidance.');
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

    final bmi = _bmi;
    return CalcScaffold(
      title: 'BMI',
      children: [
        CalcField(label: 'Weight', suffix: 'kg', controller: _weight),
        CalcField(label: 'Height', suffix: 'cm', controller: _height),
        if (bmi != null) ...[
          ResultCard(
            headline: 'YOUR BMI',
            rows: [
              ResultRow('BMI', bmi.toStringAsFixed(1), emphasize: true),
              ResultRow('Category', _category(bmi).$1),
            ],
            footnote: _category(bmi).$2 +
                '\n\nBMI is a crude screening tool. Muscular individuals often '
                'score "overweight" despite being lean. Use alongside body '
                'fat % and waist measurement.',
          ),
        ] else
          const ResultCard(
            headline: 'FILL YOUR DETAILS',
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
