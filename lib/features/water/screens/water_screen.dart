import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/water_provider.dart';

/// Water intake tab. A large animated beaker with volume marks on the
/// left, progress stats, quick-add chips, and an inline custom-amount
/// input — all on one screen so logging is one tap away.
class WaterScreen extends ConsumerStatefulWidget {
  const WaterScreen({super.key});

  @override
  ConsumerState<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends ConsumerState<WaterScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _levelController;
  late Animation<double> _levelAnimation;

  final _customController = TextEditingController();
  final _customFocus = FocusNode();

  /// The total (in ml) currently represented by the beaker's fill line.
  /// Drives the tween target when the real total changes.
  int _displayedTotal = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _levelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _levelAnimation = const AlwaysStoppedAnimation<double>(0);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _levelController.dispose();
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _syncLevel(int newTotal) {
    if (newTotal == _displayedTotal) return;
    _levelAnimation = Tween<double>(
      begin: _displayedTotal.toDouble(),
      end: newTotal.toDouble(),
    ).animate(
      CurvedAnimation(parent: _levelController, curve: Curves.easeOutCubic),
    );
    _displayedTotal = newTotal;
    _levelController.forward(from: 0);
  }

  Future<void> _add(int ml) async {
    final add = ref.read(addWaterLogProvider);
    await add(ml);
  }

  Future<void> _submitCustom() async {
    final ml = int.tryParse(_customController.text.trim());
    if (ml == null || ml <= 0 || ml > 5000) return;
    _customController.clear();
    _customFocus.unfocus();
    await _add(ml);
  }

  Future<void> _openEditTarget() async {
    final current = ref.read(dailyWaterTargetProvider);
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _TargetDialog(initial: current),
    );
    if (result != null) {
      await ref.read(dailyWaterTargetProvider.notifier).set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(todayWaterTotalMlProvider);
    final target = ref.watch(dailyWaterTargetProvider);

    if (_displayedTotal != total) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncLevel(total);
      });
    }

    final pct = target == 0 ? 0.0 : (total / target).clamp(0.0, 1.25);
    // Cap scale so the beaker shows comfortable headroom above target
    // and never lets a big overflow push the fill to the ceiling.
    final maxMl = math.max(target * 1.1, total.toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('Water', style: AppTypography.sectionHeader),
        actions: [
          IconButton(
            tooltip: 'Daily target',
            icon: const Icon(Icons.flag_outlined,
                color: AppColors.textSecondary, size: 22),
            onPressed: _openEditTarget,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Big beaker ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _waveController,
                        _levelController,
                      ]),
                      builder: (_, __) {
                        final animatedMl = _levelController.isAnimating
                            ? _levelAnimation.value
                            : _displayedTotal.toDouble();
                        return CustomPaint(
                          painter: _BeakerPainter(
                            fillMl: animatedMl,
                            maxMl: maxMl,
                            wavePhase: _waveController.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _formatLiters(total),
                    style: AppTypography.sectionHeader.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${_formatLiters(target)} · ${(pct * 100).round()}%',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Quick add ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _QuickAddChip(
                    label: '100 ml',
                    icon: Icons.water_drop_outlined,
                    onTap: () => _add(100),
                  ),
                  const SizedBox(width: 8),
                  _QuickAddChip(
                    label: '250 ml',
                    icon: Icons.local_drink_outlined,
                    onTap: () => _add(250),
                  ),
                  const SizedBox(width: 8),
                  _QuickAddChip(
                    label: '500 ml',
                    icon: Icons.sports_bar_outlined,
                    onTap: () => _add(500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Inline custom amount + add CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _CustomAmountBar(
                controller: _customController,
                focusNode: _customFocus,
                onSubmit: _submitCustom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLiters(int ml) {
  final l = ml / 1000;
  return '${l.toStringAsFixed(l >= 10 ? 1 : 2)} L';
}

// ════════════════════════════════════════════════════════════
// Beaker painter
// ════════════════════════════════════════════════════════════

class _BeakerPainter extends CustomPainter {
  final double fillMl;
  final double maxMl;
  final double wavePhase;

  _BeakerPainter({
    required this.fillMl,
    required this.maxMl,
    required this.wavePhase,
  });

  /// Horizontal space reserved on the left of the canvas for volume
  /// marks and their labels.
  static const double _labelsArea = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final neckH = h * 0.04;
    // Shift the actual beaker body to the right so the labels area on
    // the left has room for tick marks + volume captions.
    final body = Rect.fromLTWH(
      _labelsArea,
      neckH,
      w - _labelsArea,
      h - neckH,
    );
    final bodyRRect = RRect.fromRectAndCorners(
      body,
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: const Radius.circular(28),
      bottomRight: const Radius.circular(28),
    );

    // 1) Glass background
    final glassFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceElevated.withOpacity(0.55),
          AppColors.surface.withOpacity(0.9),
        ],
      ).createShader(body);
    canvas.drawRRect(bodyRRect, glassFill);

    // 2) Water — clipped to the body
    canvas.save();
    canvas.clipRRect(bodyRRect);

    final maxDenom = maxMl <= 0 ? 1.0 : maxMl;
    final rawLevel = (fillMl / maxDenom).clamp(0.0, 1.0);
    // Reserve a little headroom at the top so the wave peak doesn't clip
    // flush against the rim.
    final levelY = body.bottom - rawLevel * (body.height - 6);

    // Back wave (lighter, slightly faster)
    _drawWave(
      canvas,
      body,
      baselineY: levelY,
      amplitude: rawLevel > 0.01 ? 5 : 0,
      wavelength: body.width * 1.1,
      phase: wavePhase * 1.3,
      color: const Color(0xFF1E90FF).withOpacity(0.55),
    );

    // Front wave (main water colour)
    _drawWave(
      canvas,
      body,
      baselineY: levelY + 2,
      amplitude: rawLevel > 0.01 ? 7 : 0,
      wavelength: body.width * 1.4,
      phase: -wavePhase,
      color: const Color(0xFF2E9BFF).withOpacity(0.85),
    );

    // Subtle gloss highlight on the water surface
    if (rawLevel > 0.03) {
      final glossPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(body.left, levelY, body.width, 28));
      canvas.drawRect(
          Rect.fromLTWH(body.left, levelY, body.width, 28), glossPaint);
    }

    canvas.restore();

    // 3) Volume marks on the left of the beaker (outside the body).
    _drawVolumeMarks(canvas, body);

    // 4) Glass stroke (on top of everything)
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.textTertiary.withOpacity(0.55);
    canvas.drawRRect(bodyRRect, stroke);

    // Left edge highlight — that premium glass sheen
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomLeft,
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.02),
        ],
      ).createShader(
          Rect.fromLTWH(body.left + 4, body.top + 8, 6, body.height * 0.6));
    final highlightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(body.left + 6, body.top + 10, 4, body.height * 0.55),
      const Radius.circular(3),
    );
    canvas.drawRRect(highlightRRect, highlight);

    // Rim ellipse to suggest an opening
    final rimRect = Rect.fromLTWH(
        body.left + 4, -neckH * 0.5, body.width - 8, neckH * 2);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.textTertiary.withOpacity(0.75);
    canvas.drawOval(rimRect, rimPaint);
  }

  /// Ticks + labels at every `step` ml on the left of the beaker.
  /// Step adapts to the current scale so we never end up with more than
  /// ~6 labels crammed into the gutter.
  void _drawVolumeMarks(Canvas canvas, Rect body) {
    if (maxMl <= 0) return;

    // Pick a step that gives 4–6 labels for any realistic daily scale.
    final int stepMl;
    if (maxMl <= 1500) {
      stepMl = 250;
    } else if (maxMl <= 3500) {
      stepMl = 500;
    } else if (maxMl <= 7000) {
      stepMl = 1000;
    } else {
      stepMl = 2000;
    }

    final tickPaint = Paint()
      ..color = AppColors.textTertiary.withOpacity(0.55)
      ..strokeWidth = 1.0;

    final labelColor = AppColors.textTertiary.withOpacity(0.8);

    // Start at 0 and step up until we pass the scale ceiling.
    for (int ml = 0; ml <= maxMl; ml += stepMl) {
      // Skip 0 label — it clutters the bottom and the base of the beaker
      // already implies zero.
      final y = body.bottom - (ml / maxMl) * (body.height - 6);

      // Tick: short horizontal line just outside the body's left edge.
      canvas.drawLine(
        Offset(body.left - 4, y),
        Offset(body.left, y),
        tickPaint,
      );

      if (ml == 0) continue;

      final label = _formatMark(ml);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Right-align the label into the gutter.
      tp.paint(
        canvas,
        Offset(body.left - 6 - tp.width, y - tp.height / 2),
      );
    }
  }

  String _formatMark(int ml) {
    final l = ml / 1000.0;
    if (l == l.roundToDouble()) return '${l.toInt()}L';
    return '${l.toStringAsFixed(1)}L';
  }

  void _drawWave(
    Canvas canvas,
    Rect body, {
    required double baselineY,
    required double amplitude,
    required double wavelength,
    required double phase,
    required Color color,
  }) {
    final path = Path();
    path.moveTo(body.left, body.bottom);
    path.lineTo(body.left, baselineY);

    const step = 3.0;
    for (double x = body.left; x <= body.right; x += step) {
      final dx = x - body.left;
      final y = baselineY +
          math.sin((dx / wavelength) * 2 * math.pi + phase) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(body.right, body.bottom);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BeakerPainter old) =>
      old.fillMl != fillMl ||
      old.maxMl != maxMl ||
      old.wavePhase != wavePhase;
}

// ════════════════════════════════════════════════════════════
// Chip + inline input widgets
// ════════════════════════════════════════════════════════════

class _QuickAddChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAddChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline amount input + red Add button. Replaces the old "Custom"
/// modal dialog for lower-friction logging.
class _CustomAmountBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _CustomAmountBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_outlined,
                    color: AppColors.textTertiary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmit(),
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600),
                    cursorColor: AppColors.primaryRed,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Custom amount',
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Text(
                  'ml',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Log',
                  style: AppTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// Target dialog (still accessed via the flag icon in the AppBar)
// ════════════════════════════════════════════════════════════

class _TargetDialog extends StatefulWidget {
  final int initial;
  const _TargetDialog({required this.initial});

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final TextEditingController _controller;
  static const _presets = [2000, 2500, 3000, 3500];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int ml) {
    _controller.text = ml.toString();
    setState(() {});
  }

  void _submit() {
    final ml = int.tryParse(_controller.text.trim());
    if (ml == null || ml < 250 || ml > 10000) return;
    Navigator.pop(context, ml);
  }

  @override
  Widget build(BuildContext context) {
    final current = int.tryParse(_controller.text);
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text('Daily target', style: AppTypography.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            cursorColor: AppColors.primaryRed,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              suffixText: 'ml',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryRed),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final active = current == p;
              return GestureDetector(
                onTap: () => _pick(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryRed : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? Colors.transparent : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    '${(p / 1000).toStringAsFixed(p % 1000 == 0 ? 1 : 2)} L',
                    style: AppTypography.caption.copyWith(
                      color: active ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Save',
              style:
                  AppTypography.body.copyWith(color: AppColors.primaryRed)),
        ),
      ],
    );
  }
}
