// Generates Spendly branding PNGs (launcher icon, adaptive foreground, splash)
// from code — no external design file or font glyphs required (text glyphs
// don't render reliably in the headless test harness, so the ₹ is drawn as
// vector strokes).
//
// Run with: flutter test tool/gen_branding.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const green1 = Color(0xFF2FBF71);
const green2 = Color(0xFF12784E);
const greenDark = Color(0xFF0E5A3E);

Future<void> _writePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('wrote $path (${bytes.length} bytes)');
}

/// Draws a rupee "₹" as vector strokes centered at [center] with height [h].
void _drawRupee(Canvas canvas, Offset center, double h, Color color) {
  final p = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.13
    ..strokeCap = StrokeCap.round;
  final left = center.dx - h * 0.28;
  final right = center.dx + h * 0.28;
  final top = center.dy - h * 0.5;
  // Two horizontal bars.
  canvas.drawLine(Offset(left, top), Offset(right, top), p);
  canvas.drawLine(Offset(left, top + h * 0.26), Offset(right, top + h * 0.26), p);
  // Curved hook down to a diagonal leg.
  final path = Path()
    ..moveTo(right - h * 0.06, top)
    ..cubicTo(left + h * 0.1, top + h * 0.18, left + h * 0.05, top + h * 0.55,
        left + h * 0.55, top + h * 0.55)
    ..lineTo(right, top + h * 1.0);
  canvas.drawPath(path, p);
}

/// Draws the stylized ribbon "S" + ₹ coin centered in a [size] box.
void _drawMark(Canvas canvas, double size, {double scale = 1.0}) {
  final c = size / 2;
  final r = size * 0.30 * scale;

  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(c - r, c - r),
      Offset(c + r, c + r),
      [green1, green2],
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.14 * scale
    ..strokeCap = StrokeCap.round;

  final topRect =
      Rect.fromCircle(center: Offset(c, c - r * 0.55), radius: r * 0.72);
  final bottomRect =
      Rect.fromCircle(center: Offset(c, c + r * 0.55), radius: r * 0.72);
  final path = Path()
    ..addArc(topRect, math.pi * 0.15, math.pi * 1.25)
    ..addArc(bottomRect, math.pi * 1.15, math.pi * 1.25);
  canvas.drawPath(path, paint);

  // ₹ coin.
  final coinCenter = Offset(c + r * 0.15, c);
  final coinR = r * 0.44;
  canvas.drawCircle(coinCenter, coinR, Paint()..color = Colors.white);
  _drawRupee(canvas, coinCenter, coinR * 1.1, greenDark);
}

Future<ui.Image> _renderIcon(double size, {bool background = true}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size, size),
        [const Color(0xFF12784E), const Color(0xFF0A3D2A)],
      );
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size),
      Radius.circular(size * 0.22),
    );
    canvas.drawRRect(rrect, bg);
  }
  _drawMark(canvas, size, scale: background ? 1.0 : 0.62);
  final pic = recorder.endRecording();
  return pic.toImage(size.toInt(), size.toInt());
}

Future<ui.Image> _renderSplash(double side) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Transparent bg; native splash paints the color. Just the mark, centered.
  _drawMark(canvas, side, scale: 1.0);
  final pic = recorder.endRecording();
  return pic.toImage(side.toInt(), side.toInt());
}

void main() {
  testWidgets('icon', (tester) async {
    await _writePng(await _renderIcon(1024, background: true),
        'assets/branding/spendly_icon.png');
  });
  testWidgets('adaptive foreground', (tester) async {
    await _writePng(await _renderIcon(1024, background: false),
        'assets/branding/spendly_icon_fg.png');
  });
  testWidgets('splash', (tester) async {
    await _writePng(await _renderSplash(768),
        'assets/branding/spendly_splash.png');
  });
}
