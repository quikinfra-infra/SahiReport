// lib/features/field_user/screens/field_home_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../repositories/submission_repository.dart';

class FieldHomeScreen extends ConsumerStatefulWidget {
  const FieldHomeScreen({super.key});

  @override
  ConsumerState<FieldHomeScreen> createState() => _FieldHomeScreenState();
}

class _FieldHomeScreenState extends ConsumerState<FieldHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _repo = SubmissionRepository();
  final _picker = ImagePicker();

  List<XFile> _images = [];
  List<Uint8List> _imagePreviews = [];
  Position? _position;
  bool _gpsLoading = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _gpsError;

  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Location permission denied';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
        _gpsLoading = false;
      });
    } catch (e) {
      setState(() {
        _gpsError = 'Could not get location. Tap to retry.';
        _gpsLoading = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= _maxPhotos) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _images = [..._images, image];
          _imagePreviews = [..._imagePreviews, bytes];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open camera: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images = List.from(_images)..removeAt(index);
      _imagePreviews = List.from(_imagePreviews)..removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS location required. Please wait or tap retry.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 photo is required as evidence.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fieldUser = ref.read(authProvider).fieldUser!;
      await _repo.submitForm(
        accessCode: fieldUser.accessCode,
        projectUserId: fieldUser.id,
        projectId: fieldUser.projectId,
        ownerId: fieldUser.ownerId,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        projectName: fieldUser.projectName, // ← ADD THIS
        userName: fieldUser.name, // ← ADD THIS
        siteName: _siteCtrl.text.trim().isEmpty ? null : _siteCtrl.text.trim(),
        formText:
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        images: _images,
        imagePreviews: _imagePreviews,
      );
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Submission failed: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _siteCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _images = [];
      _imagePreviews = [];
      _submitted = false;
    });
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    final fieldUser = ref.watch(authProvider).fieldUser;

    if (_submitted) {
      return _SuccessScreen(
        onNewReport: _resetForm,
        onBackToDashboard: () {
          // userSubmissionsProvider is keyed by accessCode (see
          // submission_provider.dart and the field dashboard's
          // ref.watch call) — NOT by field user ID. Invalidating by
          // uid created a different provider instance and had no
          // effect on the dashboard's cached list, which is why a
          // logout/login was needed to see the new submission.
          final accessCode = ref.read(authProvider).fieldUser?.accessCode;
          if (accessCode != null) {
            ref.invalidate(userSubmissionsProvider(accessCode));
          }
          if (context.canPop()) {
            context.pop();
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.navyDark,
            foregroundColor: Colors.white,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Report',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(fieldUser?.projectName ?? '',
                    style: const TextStyle(
                        color: Color(0xFF7A90B8), fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Container(
                color: AppTheme.navyLight,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Color(0xFF7A90B8), size: 14),
                    const SizedBox(width: 6),
                    Text(fieldUser?.name ?? '',
                        style: const TextStyle(
                            color: Color(0xFF7A90B8), fontSize: 12)),
                    const Spacer(),
                    Text(_formatDate(DateTime.now()),
                        style: const TextStyle(
                            color: Color(0xFF7A90B8), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GPS Card
                      _GpsCard(
                        position: _position,
                        isLoading: _gpsLoading,
                        error: _gpsError,
                        onRetry: _getLocation,
                      ),
                      const SizedBox(height: 16),

                      // Site name
                      const Text('SITE / LOCATION NAME',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.grayDark,
                              letterSpacing: 0.06)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _siteCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'e.g. NH-31 Bridge, Km 14.2',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      const Text('OBSERVATION NOTES *',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.grayDark,
                              letterSpacing: 0.06)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                          'Describe what you observed at the site today...',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please add your observations'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Photos section
                      Row(
                        children: [
                          const Text('PHOTO EVIDENCE *',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.grayDark,
                                  letterSpacing: 0.06)),
                          const Spacer(),
                          Text('${_images.length}/$_maxPhotos',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _images.isEmpty
                                    ? AppTheme.error
                                    : _images.length >= _maxPhotos
                                    ? AppTheme.grayText
                                    : AppTheme.success,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Web message
                      if (kIsWeb)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(10),
                            border:
                            Border.all(color: AppTheme.warning, width: 0.5),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.smartphone,
                                  color: AppTheme.warning, size: 32),
                              SizedBox(height: 8),
                              Text('Camera not available on web',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warning)),
                              SizedBox(height: 4),
                              Text(
                                  'Please use the mobile app to capture\nphoto evidence from camera.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.warning)),
                            ],
                          ),
                        )
                      else ...[
                        // Photo grid
                        if (_imagePreviews.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _imagePreviews
                                .asMap()
                                .entries
                                .map(
                                  (e) => _ImageThumb(
                                bytes: e.value,
                                onRemove: () => _removeImage(e.key),
                              ),
                            )
                                .toList(),
                          ),
                        if (_imagePreviews.isNotEmpty)
                          const SizedBox(height: 10),

                        // Camera button
                        if (_images.length < _maxPhotos)
                          GestureDetector(
                            onTap: _takePhoto,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.grayCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _images.isEmpty
                                      ? AppTheme.error
                                      : AppTheme.grayBorder,
                                  width: _images.isEmpty ? 1 : 0.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.camera_alt,
                                      size: 32,
                                      color: _images.isEmpty
                                          ? AppTheme.error
                                          : AppTheme.navyMid),
                                  const SizedBox(height: 6),
                                  Text(
                                      _images.isEmpty
                                          ? 'Tap to take photo (required)'
                                          : 'Take another photo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _images.isEmpty
                                            ? AppTheme.error
                                            : AppTheme.navyMid,
                                      )),
                                  if (_images.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text('At least 1 photo required',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.error)),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // Max reached message
                        if (_images.length >= _maxPhotos)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.grayBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.grayBorder, width: 0.5),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 16, color: AppTheme.success),
                                SizedBox(width: 6),
                                Text('Maximum 5 photos reached',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],

                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navyMid,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_outlined,
                              color: Colors.white),
                          label: Text(
                              _submitting
                                  ? 'Submitting...'
                                  : 'Submit Daily Report',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'GPS coordinates, timestamp and photos are\nautomatically locked and cannot be modified.',
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 11, color: AppTheme.grayText),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── GPS Card ──────────────────────────────────────────────────
class _GpsCard extends StatelessWidget {
  final Position? position;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _GpsCard({
    required this.position,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.grayCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: position != null
              ? AppTheme.success
              : error != null
              ? AppTheme.error
              : AppTheme.grayBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: position != null
                  ? AppTheme.successLight
                  : error != null
                  ? AppTheme.errorLight
                  : AppTheme.grayBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: isLoading
                ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.navyMid))
                : Icon(position != null ? Icons.gps_fixed : Icons.gps_off,
                size: 18,
                color: position != null
                    ? AppTheme.success
                    : error != null
                    ? AppTheme.error
                    : AppTheme.grayText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? 'Getting your location...'
                      : position != null
                      ? 'GPS Locked'
                      : error ?? 'Location unavailable',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: position != null
                          ? AppTheme.success
                          : error != null
                          ? AppTheme.error
                          : AppTheme.grayText),
                ),
                if (position != null)
                  Text(
                      '${position!.latitude.toStringAsFixed(4)}° N, '
                          '${position!.longitude.toStringAsFixed(4)}° E',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.grayText)),
              ],
            ),
          ),
          if (error != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.navyMid,
                      fontWeight: FontWeight.w600)),
            ),
          if (position != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: AppTheme.activeBadge,
              child: const Text('Auto-locked',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }
}

// ── Image Thumb ───────────────────────────────────────────────
class _ImageThumb extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _ImageThumb({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.grayBorder, width: 0.5),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: AppTheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Success Screen ────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final VoidCallback onNewReport;
  final VoidCallback onBackToDashboard;

  const _SuccessScreen(
      {required this.onNewReport, required this.onBackToDashboard});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(40),
                ),
                child:
                const Icon(Icons.check, color: AppTheme.success, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Report Submitted!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 12),
              const Text(
                  'Your daily report has been submitted\nsuccessfully with GPS, timestamp and photos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF7A90B8), height: 1.5)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onNewReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyMid,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Another Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onBackToDashboard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2A3A5A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}