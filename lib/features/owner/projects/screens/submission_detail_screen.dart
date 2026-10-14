// lib/features/owner/projects/screens/submission_detail_screen.dart
// ─────────────────────────────────────────────────────────────
// Shows full detail for a single submission.
// • Owners pass [project] — export button appears in AppBar.
// • Field users open this screen without [project] — no export.
// Photos come from submission.imageUrls (joined in getSubmissions),
// no second DB query needed.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../models/submission_model.dart';
import '../../../../models/project_model.dart';
import '../../../../providers/auth_provider.dart';

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  final SubmissionModel submission;
  // Optional — only owners have project context for export.
  // Field users open this screen without a project so export is hidden.
  final ProjectModel? project;

  const SubmissionDetailScreen({
    super.key,
    required this.submission,
    this.project,
  });

  @override
  ConsumerState<SubmissionDetailScreen> createState() =>
      _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState
    extends ConsumerState<SubmissionDetailScreen> {
  bool _exporting = false;
  String _progress = '';
  String? _exportError;

  Future<void> _exportSubmission() async {
    // Export is only available when project context is provided (owner view)
    if (widget.project == null) return;

    final owner = ref.read(authProvider).owner;
    if (owner == null) return;

    // Pro-gate
    if (owner.isFree) {
      await UpgradeDialog.show(
        context,
        message: 'Export is a Pro feature. Upgrade to download PDF reports.',
      );
      return;
    }

    setState(() {
      _exporting = true;
      _progress = 'Preparing export…';
      _exportError = null;
    });

    try {
      // Capture the actual file path returned by the export service
      final filePath = await ExportService.exportSubmission(
        project: widget.project!,
        owner: owner,
        submission: widget.submission,
        onProgress: (msg) {
          if (mounted) setState(() => _progress = msg);
        },
      );

      if (mounted) {
        setState(() {
          _exporting = false;
          _progress = '';
        });

        // Show the real path in the UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: $filePath'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );

        // Automatically pop the share sheet so the user can easily access it
        await Share.shareXFiles(
          [XFile(filePath)],
          text: '${widget.project!.name} - ${widget.submission.siteName ?? 'Report'}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== EXPORT CRASH ===');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      if (mounted) {
        setState(() {
          _exporting = false;
          _progress = '';
          _exportError = 'Export failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.submission.imageUrls ?? [];

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.submission.userName ?? 'Field User',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(_formatDateTime(widget.submission.submittedAt),
                style: const TextStyle(
                    color: Color(0xFF7A90B8), fontSize: 11)),
          ],
        ),
        // Show download button only when project context is available (owner)
        actions: widget.project == null
            ? null
            : [
          _exporting
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export this submission',
            onPressed: _exportSubmission,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress banner
          if (_exporting)
            Container(
              color: AppTheme.navyMid.withValues(alpha: 0.08),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.navyMid),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_progress,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.navyMid)),
                  ),
                ],
              ),
            ),
          // Error banner
          if (_exportError != null)
            Container(
              color: AppTheme.errorLight,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(_exportError!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.error)),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meta card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.grayCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.grayBorder, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _MetaRow(
                          icon: Icons.person_outline,
                          label: 'Field User',
                          value: widget.submission.userName ?? 'Unknown',
                        ),
                        const Divider(height: 16),
                        _MetaRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date',
                          value: _formatDate(widget.submission.submittedAt),
                        ),
                        const Divider(height: 16),
                        _MetaRow(
                          icon: Icons.access_time,
                          label: 'Time',
                          value: _formatTime(widget.submission.submittedAt),
                        ),
                        if (widget.submission.siteName != null) ...[
                          const Divider(height: 16),
                          _MetaRow(
                            icon: Icons.location_on_outlined,
                            label: 'Site',
                            value: widget.submission.siteName!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Observation notes ──────────────────────
                  if (widget.submission.formText != null) ...[
                    const Text('OBSERVATION NOTES',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grayDark,
                            letterSpacing: 0.06)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.grayCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.grayBorder, width: 0.5),
                      ),
                      child: Text(widget.submission.formText!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.navyDark,
                              height: 1.5)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Photos ─────────────────────────────────
                  const Text('PHOTO EVIDENCE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grayDark,
                          letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  if (urls.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.grayCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.grayBorder, width: 0.5),
                      ),
                      child: const Center(
                        child: Text('No photos attached',
                            style: TextStyle(
                                color: AppTheme.grayText, fontSize: 13)),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: urls.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 4 / 3,
                      ),
                      itemBuilder: (context, i) => _PhotoTile(
                        url: urls[i],
                        allUrls: urls,
                        index: i,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── GPS + Lock card ────────────────────────
                  const Text('LOCATION & VERIFICATION',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grayDark,
                          letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.grayCard,
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: AppTheme.success, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gps_fixed,
                                color: AppTheme.success, size: 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GPS Coordinates',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.navyDark)),
                                Text(
                                    '${widget.submission.latitude.toStringAsFixed(6)}° N, '
                                        '${widget.submission.longitude.toStringAsFixed(6)}° E',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: AppTheme.activeBadge,
                              child: const Text('Locked',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.lock_clock,
                                color: AppTheme.success, size: 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Timestamp',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.navyDark)),
                                Text(
                                    _formatDateTime(
                                        widget.submission.submittedAt),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: AppTheme.activeBadge,
                              child: const Text('Locked',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        const Row(
                          children: [
                            Icon(Icons.verified_outlined,
                                color: AppTheme.success, size: 18),
                            SizedBox(width: 10),
                            Text('This submission is tamper-proof.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateTime(DateTime dt) =>
      '${_formatDate(dt)} at ${_formatTime(dt)}';
}

// ── Meta Row ──────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.grayText),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.grayText)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.navyDark)),
      ],
    );
  }
}

// ── Photo grid tile ───────────────────────────────────────────
class _PhotoTile extends StatelessWidget {
  final String url;
  final List<String> allUrls;
  final int index;
  const _PhotoTile({
    required this.url,
    required this.allUrls,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PhotoGallery(urls: allUrls, initialIndex: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppTheme.grayBg,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.navyMid, strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, _) => Container(
                color: AppTheme.grayBg,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppTheme.grayText, size: 32),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grayBorder, width: 0.5),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Swipeable fullscreen photo gallery ────────────────────────
class _PhotoGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoGallery({required this.urls, required this.initialIndex});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${_current + 1} of ${widget.urls.length}'),
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (context, i) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, _) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}