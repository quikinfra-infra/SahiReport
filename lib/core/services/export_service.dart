// lib/core/services/export_service.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../models/owner_model.dart';
import '../../models/project_model.dart';
import '../../models/submission_model.dart';

typedef ExportService = PdfExportService;

class PdfExportService {
  // ── Executive Navy & Slate Color Palette ──────────────────────
  static const PdfColor navyPrimary = PdfColor.fromInt(0xFF1B2A4A);
  static const PdfColor steelBlue = PdfColor.fromInt(0xFF3B5998);
  static const PdfColor forestGreen = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor forestGreenLight = PdfColor.fromInt(0xFFE8F5E9);
  static const PdfColor slateBg = PdfColor.fromInt(0xFFF4F6F9);
  static const PdfColor borderGray = PdfColor.fromInt(0xFFDCE1E8);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);

  /// Loads `assets/images/logo.png` (or `assets/icons/ic_launcher.png`) and
  /// normalizes it via Flutter's native codec so the PDF renderer never fails.
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    const candidatePaths = [
      'assets/images/logo.png',
      'assets/icons/ic_launcher.png',
      'assets/images/app_logo.png',
      'assets/logo.png',
    ];

    for (final path in candidatePaths) {
      try {
        final byteData = await rootBundle.load(path);
        final rawBytes = byteData.buffer.asUint8List();

        try {
          final codec = await ui.instantiateImageCodec(rawBytes);
          final frame = await codec.getNextFrame();
          final pngByteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (pngByteData != null) {
            return pw.MemoryImage(pngByteData.buffer.asUint8List());
          }
        } catch (_) {}

        return pw.MemoryImage(rawBytes);
      } catch (e) {
        debugPrint('Logo asset check skipped for $path:$e');
      }
    }
    return null;
  }

  /// Loads bundled Roboto/Poppins fonts from assets/fonts/ for crisp PDF text
  static Future<pw.ThemeData?> _loadPdfTheme() async {
    try {
      final regularData =
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return pw.ThemeData.withFont(
        base: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (_) {
      try {
        final regularData =
        await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
        final boldData = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
        return pw.ThemeData.withFont(
          base: pw.Font.ttf(regularData),
          bold: pw.Font.ttf(boldData),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Generates the PDF, saves it directly to the device Downloads folder,
  /// and opens the native Share / Save / Open PDF sheet. Returns saved file path.
  static Future<String> exportProjectReport({
    required ProjectModel project,
    required List<SubmissionModel> submissions,
    OwnerModel? owner,
  }) async {
    final pdfTheme = await _loadPdfTheme();
    final doc = pw.Document(
      title: '${project.name} - DPR Report',
      author: 'SahiReport - Aayushree Technologies India Private Limited',
      theme: pdfTheme,
    );

    // Load actual company/app logo from assets
    final pw.MemoryImage? logoImage = await _loadLogoImage();

    // Pre-fetch ALL submission photos (up to 6 per submission)
    final Map<String, List<pw.MemoryImage>> submissionPhotos = {};
    for (final sub in submissions) {
      if (sub.imageUrls != null && sub.imageUrls!.isNotEmpty) {
        final List<pw.MemoryImage> loadedImages = [];
        for (final url in sub.imageUrls!.take(6)) {
          final bytes = await _fetchImageBytes(url);
          if (bytes != null) {
            loadedImages.add(pw.MemoryImage(bytes));
          }
        }
        if (loadedImages.isNotEmpty) {
          submissionPhotos[sub.id] = loadedImages;
        }
      }
    }

    final now = DateTime.now();
    final exportDateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final displayDateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    if (submissions.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                project: project,
                owner: owner,
                exportDateStr: displayDateStr,
                logoImage: logoImage,
              ),
              pw.SizedBox(height: 14),
              _buildProjectSummaryBanner(project, 0),
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: slateBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Text(
                  'No field submissions recorded for this project yet.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(color: textMuted, fontSize: 11),
                ),
              ),
              pw.Spacer(),
              _buildFooter(context, logoImage),
            ],
          ),
        ),
      );
    } else {
      // Each submission gets its own dedicated page to prevent overlapping
      for (int i = 0; i < submissions.length; i++) {
        final sub = submissions[i];
        final photos = submissionPhotos[sub.id] ?? [];

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  project: project,
                  owner: owner,
                  exportDateStr: displayDateStr,
                  logoImage: logoImage,
                ),
                pw.SizedBox(height: 12),
                _buildProjectSummaryBanner(project, submissions.length),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: _buildSubmissionCard(
                    index: i + 1,
                    submission: sub,
                    photos: photos,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildFooter(context, logoImage),
              ],
            ),
          ),
        );
      }
    }

    final pdfBytes = await doc.save();

    final sanitizedName = project.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName =
        'SahiReport_${sanitizedName}_${exportDateStr}_${now.millisecondsSinceEpoch}.pdf';

    final file = await _savePdfToDevice(fileName, pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${project.name} - Daily Progress Report (DPR)',
      text:
      'Official Daily Progress Report for ${project.name} (Verified by SahiReport)',
    );

    return file.path;
  }

  /// Saves PDF directly into Android Public Downloads folder (or app Documents fallback)
  static Future<File> _savePdfToDevice(String fileName, Uint8List bytes) async {
    if (Platform.isAndroid) {
      try {
        final directDownloadDir = Directory('/storage/emulated/0/Download');
        if (await directDownloadDir.exists()) {
          final file = File('${directDownloadDir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);
          return file;
        }
      } catch (_) {}
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ── Top Document Header ───────────────────────────────────────
  static pw.Widget _buildHeader({
    required ProjectModel project,
    required OwnerModel? owner,
    required String exportDateStr,
    pw.MemoryImage? logoImage,
  }) {
    final companyOrOwner = (owner?.companyName?.trim().isNotEmpty == true)
        ? owner!.companyName!.trim()
        : (owner?.fullName?.trim().isNotEmpty == true
        ? owner!.fullName!.trim()
        : 'Authorized Project Owner');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: navyPrimary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              _buildLogoBadge(logoImage, size: 38, isOnDarkBg: true),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DAILY PROGRESS REPORT (DPR)',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    companyOrOwner,
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFFBFD4FF),
                      fontSize: 9.5,
                    ),
                  ),
                  if (owner?.gstin != null && owner!.gstin!.trim().isNotEmpty)
                    pw.Text(
                      'GSTIN: ${owner.gstin!.trim()}',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFF8BA3CB),
                        fontSize: 8,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: pw.BoxDecoration(
                  color: forestGreen,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'VERIFIED BY SAHIREPORT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Export Date: $exportDateStr',
                style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFFBFD4FF),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Project Metadata Banner with Explicit Description Label ──
  static pw.Widget _buildProjectSummaryBanner(
      ProjectModel project,
      int totalSubmissions,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: slateBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderGray, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PROJECT NAME',
                  style: pw.TextStyle(
                    color: textMuted,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  project.name,
                  style: pw.TextStyle(
                    color: navyPrimary,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (project.description != null &&
                    project.description!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'PROJECT DESCRIPTION:',
                    style: pw.TextStyle(
                      color: textMuted,
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    project.description!.trim(),
                    style: const pw.TextStyle(color: textDark, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'STATUS: ${project.isActive ? "ACTIVE" : "CLOSED"}',
                style: pw.TextStyle(
                  color: project.isActive ? forestGreen : textMuted,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Total Entries: $totalSubmissions',
                style: pw.TextStyle(
                  color: textDark,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Individual DPR Submission Card (Strict 1-per-page fit) ──
  static pw.Widget _buildSubmissionCard({
    required int index,
    required SubmissionModel submission,
    required List<pw.MemoryImage> photos,
  }) {
    // Match exact timestamp shown in the app UI (e.g., 17 Oct 2026 at 17:42)
    final dt = submission.submittedAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}${dt.year}';
    final time24Str =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    // Dynamic grid sizing so 1–4 photos use a 2x2 layout and 5–6 photos use a 3x2 layout
    final bool hasMoreThanFour = photos.length > 4;
    final double photoWidth = hasMoreThanFour ? 158.0 : 230.0;
    final double photoHeight = hasMoreThanFour ? 128.0 : 140.0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderGray, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Steel Blue Entry Header Bar (Uses visual divider line instead of pipe character)
          pw.Container(
            padding:
            const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const pw.BoxDecoration(
              color: steelBlue,
              borderRadius: pw.BorderRadius.vertical(
                top: pw.Radius.circular(5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'ENTRY #$index',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 1.2,
                      height: 10,
                      color: const PdfColor.fromInt(0xFF9BB4E8),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Submitted by: ${submission.userName ?? "Field User"}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '$dateStr at$time24Str',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFFE2E8F0),
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),

          // Metadata & Work Notes Body
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'Site / Location: ${(submission.siteName?.trim().isNotEmpty == true) ? submission.siteName!.trim() : "Main Project Site"}',
                          style: pw.TextStyle(
                            color: navyPrimary,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: pw.BoxDecoration(
                          color: forestGreenLight,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'GPS Verified: ${submission.latitude.toStringAsFixed(4)} N,${submission.longitude.toStringAsFixed(4)} E',
                          style: pw.TextStyle(
                            color: forestGreen,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (submission.formText != null &&
                      submission.formText!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'OBSERVATION NOTES',
                      style: pw.TextStyle(
                        color: textMuted,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: slateBg,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: borderGray, width: 0.5),
                      ),
                      child: pw.Text(
                        submission.formText!.trim(),
                        style: const pw.TextStyle(
                          color: textDark,
                          fontSize: 9,
                          lineSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (photos.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'PHOTO EVIDENCE (${photos.length})',
                      style: pw.TextStyle(
                        color: textMuted,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: pw.WrapAlignment.center,
                          children: photos.map((img) {
                            return pw.Container(
                              width: photoWidth,
                              height: photoHeight,
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(4),
                                border: pw.Border.all(
                                    color: borderGray, width: 0.6),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 4,
                                verticalRadius: 4,
                                child: pw.Image(img, fit: pw.BoxFit.cover),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page Footer with Logo & Aayushree Branding ────────────────
  static pw.Widget _buildFooter(
      pw.Context context,
      pw.MemoryImage? logoImage,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderGray, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildLogoBadge(logoImage, size: 16, isOnDarkBg: false),
              pw.SizedBox(width: 6),
              pw.Text(
                'SahiReport',
                style: pw.TextStyle(
                  color: navyPrimary,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: 1,
                height: 10,
                color: borderGray,
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Designed and Developed by: Aayushree Technologies India Private Limited',
                style: pw.TextStyle(
                  color: textMuted,
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            'Page ${context.pageNumber} of${context.pagesCount}',
            style: const pw.TextStyle(
              color: textMuted,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Software Logo Badge (Contrasting White Box on Dark Header) ──
  static pw.Widget _buildLogoBadge(
      pw.MemoryImage? logoImage, {
        required double size,
        required bool isOnDarkBg,
      }) {
    if (logoImage != null) {
      return pw.Container(
        width: size,
        height: size,
        padding: pw.EdgeInsets.all(isOnDarkBg ? size * 0.10 : size * 0.04),
        decoration: pw.BoxDecoration(
          color: isOnDarkBg ? PdfColors.white : slateBg,
          borderRadius: pw.BorderRadius.circular(size * 0.22),
          border: isOnDarkBg
              ? null
              : pw.Border.all(color: borderGray, width: 0.5),
        ),
        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: steelBlue,
        borderRadius: pw.BorderRadius.circular(size * 0.22),
      ),
      child: pw.Text(
        'SR',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: size * 0.45,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}