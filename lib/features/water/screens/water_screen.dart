import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/water_provider.dart';

/// Water intake tab. A big animated beaker at the top, quick-add chips
/// below, and today's entries in a scrollable list.
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

  Future<void> _openCustomAdd() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomAmountDialog(),
    );
    if (result != null) await _add(result);
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
    final logsAsync = ref.watch(todayWaterLogsProvider);

    if (_displayedTotal != total) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncLevel(total);
      });
    }

    final pct = target == 0 ? 0.0 : (total / target).clamp(0.0, 1.25);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
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
            // ── Beaker ──
            Expanded(
              flex: 5,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 0.62,
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
                            targetMl: target.toDouble(),
                            maxMl: math.max(target * 1.1, total.toDouble()),
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
                      fontSize: 34,
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

            const SizedBox(height: 16),

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
                  const SizedBox(width: 8),
                  _QuickAddChip(
                    label: 'Custom',
                    icon: Icons.add,
                    primary: true,
                    onTap: _openCustomAdd,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Today's log ──
            Expanded(
              flex: 4,
              child: logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No drinks logged yet.\nTap a chip above to start.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _WaterLogTile(log: logs[i]),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('Error: $e')),
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
  final double targetMl;
  final double maxMl;
  final double wavePhase;

  _BeakerPainter({
    required this.fillMl,
    required this.targetMl,
    required this.maxMl,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The beaker takes the full canvas but with some breathing room at top
    // for a neck/rim. We draw:
    //   1. Glass body (rounded rectangle, dark surface, subtle stroke)
    //   2. Water fill (clipped) with two layered sine waves
    //   3. Target line (dashed) across the inside
    //   4. Rim highlight + gloss

    final neckH = h * 0.04;
    final body = Rect.fromLTWH(0, neckH, w, h - neckH);
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
      wavelength: w * 1.1,
      phase: wavePhase * 1.3,
      color: const Color(0xFF1E90FF).withOpacity(0.55),
    );

    // Front wave (main water colour)
    _drawWave(
      canvas,
      body,
      baselineY: levelY + 2,
      amplitude: rawLevel > 0.01 ? 7 : 0,
      wavelength: w * 1.4,
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
        ).createShader(Rect.fromLTWH(0, levelY, w, 28));
      canvas.drawRect(Rect.fromLTWH(0, levelY, w, 28), glossPaint);
    }

    canvas.restore();

    // 3) Target line (inside the glass, dashed)
    if (targetMl > 0 && targetMl <= maxMl) {
      final targetY =
          body.bottom - (targetMl / maxDenom).clamp(0.0, 1.0) * body.height;
      _drawDashedLine(
        canvas,
        Offset(body.left + 12, targetY),
        Offset(body.right - 12, targetY),
        AppColors.primaryRed.withOpacity(0.85),
      );

      // "Target" pill on the right
      final tp = TextPainter(
        text: TextSpan(
          text: 'GOAL',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(body.right - tp.width - 8, targetY - 11));
    }

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
      ).createShader(Rect.fromLTWH(body.left + 4, body.top + 8, 6, body.height * 0.6));
    final highlightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(body.left + 6, body.top + 10, 4, body.height * 0.55),
      const Radius.circular(3),
    );
    canvas.drawRRect(highlightRRect, highlight);

    // Rim ellipse to suggest an opening
    final rimRect =
        Rect.fromLTWH(body.left + 4, -neckH * 0.5, body.width - 8, neckH * 2);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.textTertiary.withOpacity(0.75);
    canvas.drawOval(rimRect, rimPaint);
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
      final y =
          baselineY + math.sin((dx / wavelength) * 2 * math.pi + phase) *
              amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(body.right, body.bottom);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dashLen = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final dx = b.dx - a.dx;
    final total = dx.abs();
    double drawn = 0;
    while (drawn < total) {
      final start = Offset(a.dx + drawn, a.dy);
      final endX = a.dx + math.min(drawn + dashLen, total);
      canvas.drawLine(start, Offset(endX, a.dy), paint);
      drawn += dashLen + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BeakerPainter old) =>
      old.fillMl != fillMl ||
      old.targetMl != targetMl ||
      old.maxMl != maxMl ||
      old.wavePhase != wavePhase;
}

// ════════════════════════════════════════════════════════════
// Chip + tile widgets
// ════════════════════════════════════════════════════════════

class _QuickAddChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _QuickAddChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.primaryRed : AppColors.surface;
    final fg = primary ? Colors.white : AppColors.textPrimary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary
                  ? Colors.transparent
                  : AppColors.divider,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: fg,
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

class _WaterLogTile extends ConsumerWidget {
  final WaterLog log;
  const _WaterLogTile({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = TimeOfDay.fromDateTime(log.loggedAt).format(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E90FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.water_drop,
                size: 16, color: Color(0xFF2E9BFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${log.amountMl} ml',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(time,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: AppColors.textTertiary, size: 18),
            onPressed: () =>
                ref.read(deleteWaterLogProvider)(log.id),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Dialogs
// ════════════════════════════════════════════════════════════

class _CustomAmountDialog extends StatefulWidget {
  const _CustomAmountDialog();

  @override
  State<_CustomAmountDialog> createState() => _CustomAmountDialogState();
}

class _CustomAmountDialogState extends State<_CustomAmountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ml = int.tryParse(_controller.text.trim());
    if (ml == null || ml <= 0 || ml > 5000) return;
    Navigator.pop(context, ml);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text('Add water', style: AppTypography.cardTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _submit(),
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        cursorColor: AppColors.primaryRed,
        decoration: InputDecoration(
          hintText: 'e.g. 350',
          suffixText: 'ml',
          hintStyle: AppTypography.body
              .copyWith(color: AppColors.textTertiary),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryRed),
          ),
        ),
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
          child: Text('Add',
              style: AppTypography.body
                  .copyWith(color: AppColors.primaryRed)),
        ),
      ],
    );
  }
}

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
            decoration: InputDecoration(
              suffixText: 'ml',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: const UnderlineInputBorder(
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
                    color: active
                        ? AppColors.primaryRed
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    '${(p / 1000).toStringAsFixed(p % 1000 == 0 ? 1 : 2)} L',
                    style: AppTypography.caption.copyWith(
                      color:
                          active ? Colors.white : AppColors.textSecondary,
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
              style: AppTypography.body
                  .copyWith(color: AppColors.primaryRed)),
        ),
      ],
    );
  }
}
