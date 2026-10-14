// lib/repositories/submission_repository.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/constants/app_constants.dart';
import '../core/services/image_stamp_service.dart';
import '../models/submission_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
final supabase = Supabase.instance.client;

class SubmissionRepository {
  // ── Submit a DPR form ─────────────────────────────────────
  // Field users have no auth session, so the submission row is
  // created via the submit_report RPC (SECURITY DEFINER), which
  // validates the access code and bypasses RLS. Images are then
  // uploaded to Storage and registered via add_submission_image.
  Future<SubmissionModel> submitForm({
    required String accessCode,
    required String projectUserId,
    required String projectId,
    required String ownerId,
    required double latitude,
    required double longitude,
    required String projectName,
    required String userName,
    String? siteName,
    String? formText,
    List<XFile> images = const [],
    List<Uint8List> imagePreviews = const [],
  }) async {
    // 1. Create the submission via the secure RPC.
    final rpcResult = await supabase.rpc(
      'submit_report',
      params: {
        'p_code': accessCode,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_site_name': siteName,
        'p_form_text': formText,
      },
    );

    final data = rpcResult as Map<String, dynamic>;
    final submissionId = data['submission_id'] as String;
    final resolvedProjectId = data['project_id'] as String? ?? projectId;
    final resolvedOwnerId = data['owner_id'] as String? ?? ownerId;
    final timestamp = DateTime.now();

    // 2. Upload images with stamp (Storage upload stays client-side;
    //    the DB row is written via add_submission_image RPC).
    if (images.isNotEmpty) {
      if (kIsWeb) {
        await _uploadImagesWeb(
          accessCode: accessCode,
          submissionId: submissionId,
          projectId: resolvedProjectId,
          ownerId: resolvedOwnerId,
          images: images,
          imagePreviews: imagePreviews,
          projectName: projectName,
          siteName: siteName,
          userName: userName,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
        );
      } else {
        await _uploadImagesMobile(
          accessCode: accessCode,
          submissionId: submissionId,
          projectId: resolvedProjectId,
          ownerId: resolvedOwnerId,
          images: images,
          projectName: projectName,
          siteName: siteName,
          userName: userName,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
        );
      }
    }

    // 3. Trigger push notification to the owner (non-critical).
    try {
      await supabase.functions.invoke(
        'send-notification',
        body: {
          'submission_id': submissionId,
          'project_id': resolvedProjectId,
          'project_user_id': projectUserId,
        },
      );
    } catch (e) {
      debugPrint('Notification failed (non-critical): $e');
    }

    // Build a minimal model for the success screen.
    return SubmissionModel(
      id: submissionId,
      projectUserId: projectUserId,
      projectId: resolvedProjectId,
      ownerId: resolvedOwnerId,
      latitude: latitude,
      longitude: longitude,
      siteName: siteName,
      formText: formText,
      submittedAt: timestamp,
    );
  }

  // ── Mobile: compress + stamp + upload ─────────────────────
  Future<void> _uploadImagesMobile({
    required String accessCode,
    required String submissionId,
    required String projectId,
    required String ownerId,
    required List<XFile> images,
    required String projectName,
    required String userName,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? siteName,
  }) async {
    for (int i = 0; i < images.length; i++) {
      try {
        final xFile = images[i];
        final tempDir = await getTemporaryDirectory();

        // Step 1: Compress
        final compressedPath = p.join(
          tempDir.path,
          'compressed_${submissionId}_$i.jpg',
        );
        final compressed = await FlutterImageCompress.compressAndGetFile(
          xFile.path,
          compressedPath,
          quality: AppConstants.imageQuality,
          minWidth: AppConstants.imageMaxDimension,
          minHeight: AppConstants.imageMaxDimension,
        );
        if (compressed == null) continue;

        // Step 2: Read bytes and stamp
        final compressedBytes = await compressed.readAsBytes();
        final stampedBytes = await ImageStampService.stampImage(
          imageBytes: compressedBytes,
          projectName: projectName,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
          siteName: siteName,
          userName: userName,
        );

        // Step 3: Save stamped to temp file
        final stampedPath = p.join(
          tempDir.path,
          'stamped_${submissionId}_$i.jpg',
        );
        await File(stampedPath).writeAsBytes(stampedBytes);

        // Step 4: Upload
        final storagePath = '$projectId/$submissionId/photo_$i.jpg';
        await supabase.storage
            .from(AppConstants.storageBucket)
            .upload(storagePath, File(stampedPath));

        final publicUrl = supabase.storage
            .from(AppConstants.storageBucket)
            .getPublicUrl(storagePath);

        // Step 5: Save to DB via secure RPC (bypasses RLS).
        await supabase.rpc('add_submission_image', params: {
          'p_code': accessCode,
          'p_submission_id': submissionId,
          'p_storage_path': storagePath,
          'p_public_url': publicUrl,
          'p_file_size_kb': (stampedBytes.length / 1024).round(),
        });
      } catch (e) {
        debugPrint('Mobile image upload failed at index $i: $e');
      }
    }
  }

  // ── Web: stamp + upload bytes ─────────────────────────────
  Future<void> _uploadImagesWeb({
    required String accessCode,
    required String submissionId,
    required String projectId,
    required String ownerId,
    required List<XFile> images,
    required List<Uint8List> imagePreviews,
    required String projectName,
    required String userName,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? siteName,
  }) async {
    for (int i = 0; i < images.length; i++) {
      try {
        final bytes = i < imagePreviews.length
            ? imagePreviews[i]
            : await images[i].readAsBytes();

        // Stamp the image
        final stampedBytes = await ImageStampService.stampImage(
          imageBytes: bytes,
          projectName: projectName,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
          siteName: siteName,
          userName: userName,
        );

        final storagePath = '$projectId/$submissionId/photo_$i.jpg';

        await supabase.storage
            .from(AppConstants.storageBucket)
            .uploadBinary(storagePath, stampedBytes);

        final publicUrl = supabase.storage
            .from(AppConstants.storageBucket)
            .getPublicUrl(storagePath);

        await supabase.rpc('add_submission_image', params: {
          'p_code': accessCode,
          'p_submission_id': submissionId,
          'p_storage_path': storagePath,
          'p_public_url': publicUrl,
          'p_file_size_kb': (stampedBytes.length / 1024).round(),
        });
      } catch (e) {
        debugPrint('Web image upload failed at index $i: $e');
      }
    }
  }

  // ── Fetch submissions for ONE field user ─────────────────
  // Field users have NO auth session, so a direct table query is
  // blocked by RLS. Instead we call a SECURITY DEFINER RPC that
  // takes the user's ACCESS CODE, resolves it server-side, and
  // returns only that user's submissions (with nested project_users
  // and submission_images, matching SubmissionModel.fromJson).
  Future<List<SubmissionModel>> getUserSubmissions(String accessCode) async {
    final response = await supabase.rpc(
      'get_user_submissions',
      params: {'p_code': accessCode},
    );

    return (response as List)
        .map((json) => SubmissionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── Fetch submissions for a project ──────────────────────
  Future<List<SubmissionModel>> getSubmissions(String projectId) async {
    final response = await supabase
        .from('submissions')
        .select('*, project_users(name), submission_images(public_url)')
        .eq('project_id', projectId)
        .order('submitted_at', ascending: false);

    return (response as List)
        .map((json) => SubmissionModel.fromJson(json))
        .toList();
  }

  // ── Fetch images for a submission ─────────────────────────
  Future<List<String>> getSubmissionImages(String submissionId) async {
    final response = await supabase
        .from('submission_images')
        .select('public_url')
        .eq('submission_id', submissionId)
        .order('uploaded_at');

    return (response as List)
        .map((json) => json['public_url'] as String)
        .toList();
  }
}