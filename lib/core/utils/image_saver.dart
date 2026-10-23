import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class ImageSaverHelper {
  /// Downloads and saves an image (URL or local file) directly to the phone's Gallery as a JPG.
  static Future<bool> saveImageToGallery({
    required BuildContext context,
    required String imagePathOrUrl,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1B2A4A),
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Downloading JPG to phone...'),
            ],
          ),
        ),
      );

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Gallery permission is required to download photos.'),
            ),
          );
          return false;
        }
      }

      Uint8List imageBytes;
      if (imagePathOrUrl.startsWith('http://') ||
          imagePathOrUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(imagePathOrUrl));
        if (response.statusCode != 200) {
          throw Exception('Server returned HTTP ${response.statusCode}');
        }
        imageBytes = response.bodyBytes;
      } else {
        final file = File(imagePathOrUrl);
        if (!await file.exists()) {
          throw Exception('Local image file not found');
        }
        imageBytes = await file.readAsBytes();
      }

      final fileName = 'SahiReport_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(
        imageBytes,
        album: 'SahiReport',
        name: fileName,
      );

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('JPG downloaded to your phone Gallery (SahiReport album)!'),
              ),
            ],
          ),
        ),
      );
      return true;
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          content: Text('Download failed: $e'),
        ),
      );
      return false;
    }
  }
}

/// Drop-in 3-Dot Button (`⋮`) to overlay on top-right of any photo thumbnail or AppBar
class PhotoThreeDotsMenu extends StatelessWidget {
  final String imageUrlOrPath;
  final VoidCallback? onViewFullScreen;

  const PhotoThreeDotsMenu({
    super.key,
    required this.imageUrlOrPath,
    this.onViewFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 20,
        ),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (value) {
          if (value == 'download_jpg') {
            ImageSaverHelper.saveImageToGallery(
              context: context,
              imagePathOrUrl: imageUrlOrPath,
            );
          } else if (value == 'view' && onViewFullScreen != null) {
            onViewFullScreen!();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'download_jpg',
            child: Row(
              children: [
                Icon(Icons.download_rounded, color: Color(0xFF1B2A4A), size: 20),
                SizedBox(width: 10),
                Text(
                  'Download JPG',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (onViewFullScreen != null)
            const PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.fullscreen_rounded, color: Color(0xFF1B2A4A), size: 20),
                  SizedBox(width: 10),
                  Text('View Full Image'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}