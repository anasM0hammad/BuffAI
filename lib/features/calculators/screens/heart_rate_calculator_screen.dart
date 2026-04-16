import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../profile/providers/profile_provider.dart';
import '../widgets/calc_scaffold.dart';

/// Karvonen target heart rate:
///   HRmax     = 220 − age
///   HRreserve = HRmax − HRrest
///   Target    = HRrest + intensity × HRreserve
///
/// We surface the standard training zones (50–95 % of HRR) so the user can
/// pick the one that matches the session they're planning.
class HeartRateCalculatorScreen extends ConsumerStatefulWidget {
  const HeartRateCalculatorScreen({super.key});

  @override
  ConsumerState<HeartRateCalculatorScreen> createState() =>
      _HeartRateCalculatorScreenState();
}

class _HeartRateCalculatorScreenState
    extends ConsumerState<HeartRateCalculatorScreen> {
  final _age = TextEditingController();
  final _resting = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _age.addListener(_update);
    _resting.addListener(_update);
  }

  void _update() => setState(() {});

  void _seedFromProfile(UserProfile p) {
    final derivedAge = p.effectiveAge;
    if (_age.text.isEmpty && derivedAge != null) {
      _age.text = derivedAge.toString();
    }
  }

  @override
  void dispose() {
    _age.removeListener(_update);
    _resting.removeListener(_update);
    _age.dispose();
    _resting.dispose();
    super.dispose();
  }

  ({int hrMax, int hrReserve, List<_Zone> zones})? _compute() {
    final age = int.tryParse(_age.text);
    final rest = int.tryParse(_resting.text);
    if (age == null || age <= 0 || age > 120) return null;
    if (rest == null || rest < 30 || rest > 120) return null;

    final hrMax = 220 - age;
    final hrReserve = hrMax - rest;
    if (hrReserve <= 0) return null;

    int target(double pct) => (rest + pct * hrReserve).round();

    final zones = <_Zone>[
      _Zone('Z1 · Recovery', '50–60 %', target(0.50), target(0.60)),
      _Zone('Z2 · Endurance', '60–70 %', target(0.60), target(0.70)),
      _Zone('Z3 · Aerobic', '70–80 %', target(0.70), target(0.80)),
      _Zone('Z4 · Threshold', '80–90 %', target(0.80), target(0.90)),
      _Zone('Z5 · Max effort', '90–100 %', target(0.90), hrMax),
    ];

    return (hrMax: hrMax, hrReserve: hrReserve, zones: zones);
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

    final result = _compute();

    return CalcScaffold(
      title: 'Target Heart Rate',
      children: [
        CalcField(
          label: 'Age',
          suffix: 'years',
          controller: _age,
          allowDecimal: false,
        ),
        CalcField(
          label: 'Resting heart rate',
          suffix: 'bpm',
          controller: _resting,
          allowDecimal: false,
        ),
        if (result != null) ...[
          ResultCard(
            headline: 'BASELINE',
            rows: [
              ResultRow(
                'Estimated max HR',
                '${result.hrMax} bpm',
                emphasize: true,
              ),
              ResultRow('Heart rate reserve', '${result.hrReserve} bpm'),
            ],
            footnote: 'HRmax uses the 220 − age estimate. Karvonen blends '
                'this with your resting HR for personalized zones below.',
          ),
          const SizedBox(height: 16),
          Text(
            'TRAINING ZONES',
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...result.zones.map((z) => _ZoneRow(zone: z)),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enter your age and resting heart rate to see your zones.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
        const SizedBox(height: 24),
        _Disclaimer(
          'These are estimates based on the standard Karvonen formula. '
          'They are not medical advice. True maximum heart rate and safe '
          'training intensities vary by individual. Consult a physician or '
          'certified coach before training at high intensities, especially '
          'if you have any cardiovascular concerns.',
        ),
      ],
    );
  }
}

class _Zone {
  final String name;
  final String pct;
  final int low;
  final int high;
  const _Zone(this.name, this.pct, this.low, this.high);
}

class _ZoneRow extends StatelessWidget {
  final _Zone zone;
  const _ZoneRow({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  zone.pct,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            '${zone.low}–${zone.high}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'bpm',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;
  const _Disclaimer(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
