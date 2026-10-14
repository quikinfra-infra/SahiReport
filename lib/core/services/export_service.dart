// lib/core/services/export_service.dart
//
// Two export modes:
//   1. SUBMISSION export — single submission as PDF, photos embedded
//   2. PROJECT export — all submissions sorted date/time, photos embedded
//
// Photos are fetched as bytes and embedded directly — no links.
// Missing/failed photos show a placeholder box rather than crashing.
// Files are saved to the device Downloads folder.
//
// Photo embedding is deliberately sequential (not parallel) to avoid
// hammering Supabase Storage with 50+ concurrent requests on large
// project exports. Shows progress via a callback so the UI can update.
//
// Font: Roboto (assets/fonts/) — supports Unicode, Latin, Devanagari,
// and other Indian scripts. Helvetica (dart_pdf default) has no Unicode
// support and causes export failures with non-ASCII text.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/owner_model.dart';
import '../../models/project_model.dart';
import '../../models/submission_model.dart';

class ExportService {
  ExportService._();

  static final _displayFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final _fileDateFmt = DateFormat('yyyyMMdd_HHmm');

  // ── Font cache (loaded once per app session) ──────────────
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _loadFonts() async {
    if (_regularFont != null) return; // already loaded
    final regularData =
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData =
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  static pw.ThemeData _theme() => pw.ThemeData.withFont(
    base: _regularFont!,
    bold: _boldFont!,
    italic: _regularFont!,
    boldItalic: _boldFont!,
  );

  // ── Save file to Downloads folder ────────────────────────
  static Future<String> _saveToDownloads(
      String filename, Uint8List bytes) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      final downloadsDir = Directory('/storage/emulated/0/Download/SahiReport');
      try {
        await downloadsDir.create(recursive: true);
        final file = File('${downloadsDir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (e) {
        debugPrint('Failed to write to public Downloads, using fallback: $e');
        final extDir = await getExternalStorageDirectory();
        final fallbackDir = Directory('${extDir!.path}/SahiReport');
        await fallbackDir.create(recursive: true);
        final file = File('${fallbackDir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/SahiReport');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }

  // ── Fetch image bytes from URL ────────────────────────────
  static Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close();
      return bytes;
    } catch (e) {
      debugPrint('Image fetch failed for $url: $e');
      return null;
    }
  }

  // ── Photo placeholder (shown when fetch fails) ────────────
  static pw.Widget _photoPlaceholder() {
    return pw.Container(
      width: double.infinity,
      height: 60,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text('Photo unavailable',
            style: pw.TextStyle(
                font: _regularFont,
                fontSize: 9,
                color: PdfColors.grey600)),
      ),
    );
  }

  // ── PDF header (first page only) ─────────────────────────
  static pw.Widget _pdfHeader({
    required ProjectModel project,
    required OwnerModel owner,
    required String subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          (owner.companyName?.trim().isNotEmpty ?? false)
              ? owner.companyName!
              : (owner.fullName ?? owner.email),
          style: pw.TextStyle(
              font: _regularFont, fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(project.name,
            style: pw.TextStyle(
                font: _boldFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold)),
        pw.Text(subtitle,
            style: pw.TextStyle(
                font: _regularFont, fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Build one submission block with embedded photos ───────
  static Future<List<pw.Widget>> _submissionBlockWidgets(
      SubmissionModel s, {
        required void Function(String) onProgress,
      }) async {
    final widgets = <pw.Widget>[];

    // 1. Header Row
    widgets.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              (s.siteName?.trim().isNotEmpty ?? false)
                  ? s.siteName!
                  : 'Untitled site',
              style: pw.TextStyle(
                  font: _boldFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Container(
            padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: s.isReviewed ? PdfColors.green50 : PdfColors.orange50,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              s.isReviewed ? 'Reviewed' : 'Pending review',
              style: pw.TextStyle(
                font: s.isReviewed ? _regularFont : _regularFont,
                fontSize: 8,
                color:
                s.isReviewed ? PdfColors.green800 : PdfColors.orange800,
              ),
            ),
          ),
        ],
      ),
    );

    widgets.add(pw.SizedBox(height: 6));

    // 2. Metadata
    widgets.add(
      pw.Text(
        'By ${s.userName ?? 'Field User'} · '
            '${_displayFmt.format(s.submittedAt.toLocal())}',
        style: pw.TextStyle(
            font: _regularFont, fontSize: 9, color: PdfColors.grey600),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(
      pw.Text(
        'GPS: ${s.latitude.toStringAsFixed(6)}, '
            '${s.longitude.toStringAsFixed(6)}',
        style: pw.TextStyle(
            font: _regularFont, fontSize: 9, color: PdfColors.grey600),
      ),
    );

    // 3. Form Text
    if (s.formText?.trim().isNotEmpty ?? false) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Text(s.formText!,
            style: pw.TextStyle(font: _regularFont, fontSize: 10)),
      );
    }

    widgets.add(pw.SizedBox(height: 10));

    // 4. Photos (Rendered individually with height limits)
    if (s.imageUrls != null && s.imageUrls!.isNotEmpty) {
      widgets.add(
        pw.Text(
          '${s.imageUrls!.length} photo'
              '${s.imageUrls!.length == 1 ? '' : 's'}:',
          style: pw.TextStyle(
              font: _boldFont, fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 6));

      for (var i = 0; i < s.imageUrls!.length; i++) {
        onProgress('Fetching photo ${i + 1} of ${s.imageUrls!.length}'
            ' for ${s.siteName ?? 'submission'}...');
        final bytes = await _fetchImageBytes(s.imageUrls![i]);
        if (bytes != null) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Container(
                height: 350, // Constrains image height to prevent page overflow
                width: double.infinity,
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(
                    pw.MemoryImage(bytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        } else {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: _photoPlaceholder(),
            ),
          );
        }
      }
    }

    // 5. Bottom Separator
    widgets.add(pw.SizedBox(height: 16));
    widgets.add(pw.Divider(color: PdfColors.grey300, thickness: 0.5));
    widgets.add(pw.SizedBox(height: 16));

    return widgets;
  }

  // ── EXPORT 1: Single submission PDF ──────────────────────
  static Future<String> exportSubmission({
    required ProjectModel project,
    required OwnerModel owner,
    required SubmissionModel submission,
    required void Function(String) onProgress,
  }) async {
    onProgress('Loading fonts...');
    await _loadFonts();

    onProgress('Building PDF...');
    final widgets = await _submissionBlockWidgets(submission, onProgress: onProgress);

    final doc = pw.Document(theme: _theme());
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => ctx.pageNumber > 1
            ? pw.SizedBox()
            : _pdfHeader(
          project: project,
          owner: owner,
          subtitle:
          'Submission by ${submission.userName ?? 'Field User'} · '
              '${_displayFmt.format(submission.submittedAt.toLocal())}',
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: _regularFont,
                  fontSize: 8,
                  color: PdfColors.grey500)),
        ),
        build: (ctx) => widgets,
      ),
    );

    onProgress('Saving to Downloads...');
    final sitePart = (submission.siteName?.trim().isNotEmpty ?? false)
        ? submission.siteName!
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        : 'submission';
    final filename =
        '${sitePart}_${_fileDateFmt.format(submission.submittedAt)}.pdf';
    final bytes = await doc.save();
    return _saveToDownloads(filename, bytes);
  }

  // ── EXPORT 2: Full project PDF (all submissions) ──────────
  static Future<String> exportProject({
    required ProjectModel project,
    required OwnerModel owner,
    required List<SubmissionModel> submissions,
    required void Function(String) onProgress,
  }) async {
    onProgress('Loading fonts...');
    await _loadFonts();

    final sorted = [...submissions]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

    onProgress('Building project report...');

    final allWidgets = <pw.Widget>[];
    for (var i = 0; i < sorted.length; i++) {
      onProgress('Processing submission ${i + 1} of ${sorted.length}...');
      final subWidgets = await _submissionBlockWidgets(sorted[i], onProgress: onProgress);
      allWidgets.addAll(subWidgets);
    }

    final doc = pw.Document(theme: _theme());
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => ctx.pageNumber > 1
            ? pw.SizedBox()
            : _pdfHeader(
          project: project,
          owner: owner,
          subtitle: '${sorted.length} submission'
              '${sorted.length == 1 ? '' : 's'} · '
              'Generated ${_displayFmt.format(DateTime.now())}',
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: _regularFont,
                  fontSize: 8,
                  color: PdfColors.grey500)),
        ),
        build: (ctx) => allWidgets,
      ),
    );

    onProgress('Saving to Downloads...');
    final safeName = project.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final filename =
        '${safeName}_full_report_${_fileDateFmt.format(DateTime.now())}.pdf';
    final bytes = await doc.save();
    return _saveToDownloads(filename, bytes);
  }
}