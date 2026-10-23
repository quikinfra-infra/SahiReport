import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/image_saver.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageSource; // Can be remote URL or local file path
  final String title;
  final String? subtitle;

  const FullScreenImageViewer({
    super.key,
    required this.imageSource,
    this.title = 'Site Photo',
    this.subtitle,
  });

  /// Quick static method to open the viewer dialog directly from anywhere
  static void open(
      BuildContext context, {
        required String imageSource,
        String title = 'Site Photo',
        String? subtitle,
      }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageSource: imageSource,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isSaving = false;

  bool get _isNetwork =>
      widget.imageSource.startsWith('http://') ||
          widget.imageSource.startsWith('https://');

  Future<void> _handleDownload() async {
    setState(() => _isSaving = true);
    await ImageSaverHelper.saveImageToGallery(
      context: context,
      imagePathOrUrl: widget.imageSource,
    );
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2A4A), // Executive Navy
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Save Image to Gallery',
            onPressed: _handleDownload,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.8,
          maxScale: 4.0,
          child: _isNetwork
              ? Image.network(
            widget.imageSource,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          )
              : Image.file(
            File(widget.imageSource),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}