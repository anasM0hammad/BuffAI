import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../widgets/calc_scaffold.dart';

enum _Sex { male, female }

enum _Activity {
  sedentary('Sedentary', 1.2, 'Little or no exercise'),
  light('Light', 1.375, '1–3 training days / week'),
  moderate('Moderate', 1.55, '3–5 training days / week'),
  hard('Hard', 1.725, '6–7 intense days / week'),
  athlete('Athlete', 1.9, '2x/day or physical job');

  const _Activity(this.label, this.multiplier, this.description);
  final String label;
  final double multiplier;
  final String description;
}

enum _Goal {
  cutAggressive('Aggressive cut', -500),
  cut('Cut', -300),
  maintain('Maintain', 0),
  leanBulk('Lean bulk', 300),
  bulk('Bulk', 500);

  const _Goal(this.label, this.offset);
  final String label;
  final int offset;
}

/// BMR via Mifflin-St Jeor, TDEE via activity multiplier, calorie target
/// via goal offset, macros via protein 2g/kg, fat 25% kcal, carbs rest.
class EnergyCalculatorScreen extends ConsumerStatefulWidget {
  const EnergyCalculatorScreen({super.key});

  @override
  ConsumerState<EnergyCalculatorScreen> createState() =>
      _EnergyCalculatorScreenState();
}

class _EnergyCalculatorScreenState
    extends ConsumerState<EnergyCalculatorScreen> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _age = TextEditingController();

  _Sex _sex = _Sex.male;
  _Activity _activity = _Activity.moderate;
  _Goal _goal = _Goal.maintain;

  /// Tracks whether the user has manually changed _sex, so that a later
  /// profile-load doesn't overwrite their choice.
  bool _sexTouchedByUser = false;

  @override
  void initState() {
    super.initState();
    _weight.addListener(() => setState(() {}));
    _height.addListener(() => setState(() {}));
    _age.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _seedFromProfile(ref.read(userProfileProvider));
    });
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserProfile p) {
    if (_weight.text.isEmpty && p.weightKg != null) {
      _weight.text = _fmtNum(p.weightKg!);
    }
    if (_height.text.isEmpty && p.heightCm != null) {
      _height.text = _fmtNum(p.heightCm!);
    }
    final derivedAge = p.effectiveAge;
    if (_age.text.isEmpty && derivedAge != null) {
      _age.text = derivedAge.toString();
    }
    if (!_sexTouchedByUser && p.gender != Gender.unspecified) {
      final newSex = p.gender == Gender.male ? _Sex.male : _Sex.female;
      if (_sex != newSex) setState(() => _sex = newSex);
    }
  }

  double? get _bmr {
    final w = double.tryParse(_weight.text.trim());
    final h = double.tryParse(_height.text.trim());
    final a = int.tryParse(_age.text.trim());
    if (w == null || h == null || a == null) return null;
    if (w <= 0 || h <= 0 || a <= 0) return null;
    // Mifflin-St Jeor.
    final base = 10 * w + 6.25 * h - 5 * a;
    return _sex == _Sex.male ? base + 5 : base - 161;
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
    );

    final bmr = _bmr;
    return CalcScaffold(
      title: 'Energy & Macros',
      children: [
        CalcField(
          label: 'Weight',
          suffix: 'kg',
          controller: _weight,
        ),
        CalcField(
          label: 'Height',
          suffix: 'cm',
          controller: _height,
        ),
        CalcField(
          label: 'Age',
          suffix: 'years',
          controller: _age,
          allowDecimal: false,
        ),
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
        CalcSegment<_Activity>(
          label: 'Activity level',
          options: _Activity.values,
          display: (a) => a.label,
          value: _activity,
          onChanged: (v) => setState(() => _activity = v),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Text(
            _activity.description,
            style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 12),
          ),
        ),
        CalcSegment<_Goal>(
          label: 'Goal',
          options: _Goal.values,
          display: (g) => g.label,
          value: _goal,
          onChanged: (v) => setState(() => _goal = v),
        ),
        if (bmr != null) _buildResult(bmr) else _needsInput(),
      ],
    );
  }

  Widget _needsInput() => const ResultCard(
        headline: 'FILL YOUR DETAILS',
        rows: [ResultRow('', '—')],
        footnote:
            'We use the Mifflin-St Jeor equation — considered the most accurate '
            'predictive formula for resting metabolism.',
      );

  Widget _buildResult(double bmr) {
    final tdee = bmr * _activity.multiplier;
    final target = tdee + _goal.offset;
    final weight = double.tryParse(_weight.text.trim()) ?? 0;

    // Protein: 2.0 g/kg (cut)/1.8 g/kg (maintain/bulk) — keeping it simple at 2.0.
    final protein = weight > 0 ? weight * 2.0 : 0.0;
    final fat = (target * 0.25) / 9; // 25% kcal from fat
    final proteinKcal = protein * 4;
    final fatKcal = fat * 9;
    final carbsKcal = (target - proteinKcal - fatKcal).clamp(0, double.infinity);
    final carbs = carbsKcal / 4;

    return ResultCard(
      headline: 'YOUR NUMBERS',
      rows: [
        ResultRow('BMR', '${bmr.round()} kcal'),
        ResultRow('TDEE (maintenance)', '${tdee.round()} kcal'),
        ResultRow(
          'Target (${_goal.label})',
          '${target.round()} kcal',
          emphasize: true,
        ),
        ResultRow('Protein', '${protein.round()} g'),
        ResultRow('Fat', '${fat.round()} g'),
        ResultRow('Carbs', '${carbs.round()} g'),
      ],
      footnote: 'Protein target at 2 g/kg body weight. Fat at 25% of total '
          'kcal. Carbs fill the remainder. Adjust weekly based on the scale.',
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
