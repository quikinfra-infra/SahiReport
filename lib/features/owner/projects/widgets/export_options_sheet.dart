// lib/features/owner/projects/widgets/export_options_sheet.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../core/services/export_service.dart';
import '../../../../models/owner_model.dart';
import '../../../../models/project_model.dart';
import '../../../../models/submission_model.dart';

class ExportOptionsSheet extends StatelessWidget {
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

  Future<void> _export(BuildContext context) async {
    if (!owner.isPro) {
      await UpgradeDialog.show(
        context,
        message: 'Project export is a Pro feature. Upgrade to download '
            'your full project report with embedded photos.',
        onUpgrade: onUpgrade,
      );
      return;
    }

    if (submissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submissions to export.')),
      );
      return;
    }

    try {
      Navigator.pop(context);
      await PdfExportService.exportProjectReport(
        project: project,
        submissions: submissions,
        owner: owner,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Export failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppTheme.error,
          ),
        );
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
          Center(
            child: Container(
              width: 40,
              height: 4,
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark)),
              if (!owner.isPro) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning,
                          letterSpacing: 0.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${submissions.length} submission'
                '${submissions.length == 1 ? '' : 's'} · '
                '${project.name}',
            style: const TextStyle(fontSize: 13, color: AppTheme.grayText),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.grayCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grayBorder, width: 0.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53935), size: 20),
                    SizedBox(width: 10),
                    Text('Full Project Report',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navyDark)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• All submissions sorted by date & time\n'
                      '• Photos embedded in the report\n'
                      '• Instant print, share & save preview',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.grayText, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _export(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text(
                'Export project report',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}