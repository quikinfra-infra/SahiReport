// lib/features/owner/projects/widgets/export_options_sheet.dart
//
// Shows two export options:
//   1. Submission-wise — export one submission at a time (from
//      submission detail screen, not here)
//   2. Project-wise — full project report, all submissions, date/time
//      ordered, photos embedded
//
// Pro gate: free owners see the upgrade dialog on either option.
// Progress dialog stays open during the async photo-fetch+PDF build.
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../core/services/export_service.dart';
import '../../../../models/owner_model.dart';
import '../../../../models/project_model.dart';
import '../../../../models/submission_model.dart';

class ExportOptionsSheet extends StatefulWidget {
  final ProjectModel project;
  final OwnerModel owner;
  final List<SubmissionModel> submissions;
  final VoidCallback? onUpgrade;

  const ExportOptionsSheet({
    super.key,
    required this.project,
    required this.owner,
    required this.submissions,
    this.onUpgrade,
  });

  static Future<void> show({
    required BuildContext context,
    required ProjectModel project,
    required OwnerModel owner,
    required List<SubmissionModel> submissions,
    VoidCallback? onUpgrade,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExportOptionsSheet(
        project: project,
        owner: owner,
        submissions: submissions,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  bool _busy = false;
  String _progress = '';
  String? _error;
  String? _savedPath;

  Future<void> _export() async {
    if (!widget.owner.isPro) {
      await UpgradeDialog.show(
        context,
        message: 'Project export is a Pro feature. Upgrade to download '
            'your full project report with embedded photos.',
        onUpgrade: widget.onUpgrade,
      );
      return;
    }

    if (widget.submissions.isEmpty) {
      setState(() => _error = 'No submissions to export.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _savedPath = null;
      _progress = 'Starting...';
    });

    try {
      final path = await ExportService.exportProject(
        project: widget.project,
        owner: widget.owner,
        submissions: widget.submissions,
        onProgress: (msg) {
          if (mounted) setState(() => _progress = msg);
        },
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _savedPath = path;
          _progress = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.grayBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text('Export project',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark)),
              if (!widget.owner.isPro) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning, letterSpacing: 0.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.submissions.length} submission'
                '${widget.submissions.length == 1 ? '' : 's'} · '
                '${widget.project.name}',
            style: const TextStyle(fontSize: 13, color: AppTheme.grayText),
          ),
          const SizedBox(height: 20),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.grayCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grayBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53935), size: 20),
                    SizedBox(width: 10),
                    Text('Full Project Report',
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navyDark)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• All submissions sorted by date & time\n'
                      '• Photos embedded in the report\n'
                      '• Saved to device Downloads folder',
                  style: TextStyle(fontSize: 12, color: AppTheme.grayText,
                      height: 1.6),
                ),
                const SizedBox(height: 4),
                Text(
                  'Note: Large projects with many photos may take a '
                      'minute to generate.',
                  style: TextStyle(fontSize: 11,
                      color: AppTheme.grayText.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Submission-wise note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.grayCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grayBorder, width: 0.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment_outlined,
                    color: AppTheme.navyMid, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Per-submission export',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.navyDark)),
                      SizedBox(height: 4),
                      Text(
                        'Tap any submission in the list to open it, '
                            'then tap the export button.',
                        style: TextStyle(fontSize: 12,
                            color: AppTheme.grayText, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress
          if (_busy) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.navyMid),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_progress,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.grayText)),
                ),
              ],
            ),
          ],

          // Success
          if (_savedPath != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Saved to Downloads/SahiReport/',
                        style: TextStyle(color: AppTheme.success,
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: const TextStyle(
                    color: AppTheme.error, fontSize: 13)),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _export,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busy
                  ? const SizedBox.shrink()
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(
                _busy ? 'Generating...' : 'Export project report',
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}