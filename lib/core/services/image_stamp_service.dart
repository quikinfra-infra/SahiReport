// lib/core/services/image_stamp_service.dart
// ─────────────────────────────────────────────────────────────
// Stamps GPS, timestamp, project name and site name
// onto the top of a photo at upload time.
// Uses Flutter's Canvas API — no extra packages needed.
// ─────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageStampService {
  // ── Main stamp function ───────────────────────────────────
  // Takes raw image bytes and returns stamped image bytes
  static Future<Uint8List> stampImage({
    required Uint8List imageBytes,
    required String projectName,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? siteName,
    String? userName,
  }) async {
    // 1. Decode original image
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;

    final imgWidth = original.width.toDouble();
    final imgHeight = original.height.toDouble();

    // 2. Calculate stamp height based on image size
    final stampHeight = (imgHeight * 0.12).clamp(80.0, 160.0);
    final padding = stampHeight * 0.12;
    final fontSize = (stampHeight * 0.18).clamp(14.0, 28.0);
    final smallSize = (fontSize * 0.78).clamp(11.0, 22.0);

    // 3. Create canvas with same size as original
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 4. Draw original image
    canvas.drawImage(original, Offset.zero, Paint());

    // 5. Draw dark overlay at TOP
    final overlayPaint = Paint()..color = const Color(0xE6000000); // 90% black
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imgWidth, stampHeight),
      overlayPaint,
    );

    // 6. Draw accent line at bottom of stamp
    final accentPaint = Paint()
      ..color = const Color(0xFF1A3A7A) // Navy blue
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, stampHeight),
      Offset(imgWidth, stampHeight),
      accentPaint,
    );

    // 7. Text paint

    // 8. Draw project name (large, top line)
    _drawText(
      canvas: canvas,
      text: '📁  $projectName',
      x: padding,
      y: padding,
      fontSize: fontSize,
      color: Colors.white,
      bold: true,
      maxWidth: imgWidth - (padding * 2),
    );

    // 9. Draw site name if provided (second line)
    double currentY = padding + fontSize + (padding * 0.5);
    if (siteName != null && siteName.isNotEmpty) {
      _drawText(
        canvas: canvas,
        text: '📍  $siteName',
        x: padding,
        y: currentY,
        fontSize: smallSize,
        color: const Color(0xFF7AADEE), // Light blue
        bold: false,
        maxWidth: imgWidth - (padding * 2),
      );
      currentY += smallSize + (padding * 0.4);
    }

    // 10. Draw timestamp and GPS on same line
    final dateStr = _formatDate(timestamp);
    final timeStr = _formatTime(timestamp);
    final gpsStr = '${latitude.toStringAsFixed(4)}°N  '
        '${longitude.toStringAsFixed(4)}°E';

    _drawText(
      canvas: canvas,
      text: '🕐  $dateStr  $timeStr     $gpsStr',
      x: padding,
      y: currentY,
      fontSize: smallSize * 0.9,
      color: const Color(0xFFCCCCCC),
      bold: false,
      maxWidth: imgWidth - (padding * 2),
    );

    // 11. Draw user name at right side if provided
    if (userName != null && userName.isNotEmpty) {
      _drawText(
        canvas: canvas,
        text: userName,
        x: imgWidth - padding,
        y: padding,
        fontSize: smallSize * 0.85,
        color: const Color(0xFF7AADEE),
        bold: false,
        maxWidth: imgWidth / 3,
        alignRight: true,
      );
    }

    // 12. Finalize and convert to bytes
    final picture = recorder.endRecording();
    final stamped = await picture.toImage(
      original.width,
      original.height,
    );
    final byteData = await stamped.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  // ── Draw text helper ──────────────────────────────────────
  static void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    required bool bold,
    required double maxWidth,
    bool alignRight = false,
  }) {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ))
      ..addText(text);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));

    final dx = alignRight ? x - paragraph.longestLine : x;
    canvas.drawParagraph(paragraph, Offset(dx, y));
  }

  // ── Date formatter ────────────────────────────────────────
  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day.toString().padLeft(2, '0')} '
        '${months[dt.month - 1]} ${dt.year}';
  }

  // ── Time formatter ────────────────────────────────────────
  static String _formatTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final am = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $am';
  }
}
