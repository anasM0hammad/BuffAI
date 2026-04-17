import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/history_provider.dart';
import '../widgets/shareable_workout_image.dart';

/// Renders a [WorkoutDay] to a PNG off-screen and hands it to the
/// platform share sheet.
///
/// The widget is rendered outside the visible widget tree so the capture
/// can grow to fit the entire workout — no scrolling, no clipping, no
/// matter how many exercises the session contained.
abstract final class WorkoutShareService {
  /// 3x keeps text crisp on high-density screens while keeping file size
  /// under a few hundred KB for typical workouts.
  static const double _pixelRatio = 3.0;

  static Future<void> shareWorkoutDay({
    required WorkoutDay day,
    required Map<int, Exercise> exerciseById,
  }) async {
    // The logo is an asset — it must be decoded before toImage() or it
    // will render as a blank box on first share.
    await _precacheAsset(const AssetImage('assets/images/logo.png'));

    final widget = ShareableWorkoutImage(
      day: day,
      exerciseById: exerciseById,
    );

    final pngBytes = await _captureOffscreen(
      child: widget,
      logicalWidth: ShareableWorkoutImage.width,
      pixelRatio: _pixelRatio,
    );

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(day.day);
    final file = File(p.join(dir.path, 'buffai-workout-$dateStr.png'));
    await file.writeAsBytes(pngBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: 'buffai-workout-$dateStr.png')],
      text: 'My BuffAI workout · ${formatDate(day.day)}',
      subject: 'BuffAI workout · ${formatDate(day.day)}',
    );
  }

  static Future<void> _precacheAsset(ImageProvider provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Builds the widget in a detached render tree, constrained to
  /// [logicalWidth] with unbounded height, then snapshots it to PNG.
  static Future<Uint8List> _captureOffscreen({
    required Widget child,
    required double logicalWidth,
    required double pixelRatio,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;

    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        physicalConstraints: BoxConstraints.tightFor(
          width: logicalWidth * pixelRatio,
        ),
        logicalConstraints: BoxConstraints.tightFor(width: logicalWidth),
        devicePixelRatio: pixelRatio,
      ),
      child: repaintBoundary,
    );

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            // Height is nominal — layout constraints come from
            // [ViewConfiguration], which leaves height unbounded so the
            // widget can grow to contain every exercise.
            size: Size(logicalWidth, 10000),
            devicePixelRatio: pixelRatio,
          ),
          child: DefaultTextStyle(
            style: AppTypography.body,
            child: ColoredBox(
              color: AppColors.background,
              child: child,
            ),
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode workout image.');
    }
    return byteData.buffer.asUint8List();
  }
}
