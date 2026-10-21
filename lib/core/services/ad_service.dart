// lib/core/services/ad_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static bool _isInitialized = false;

  /// Initializes the Google Mobile Ads SDK. Call this in main.dart.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AdMob initialization error: $e');
    }
  }

  /// Returns the Banner Ad Unit ID.
  /// Uses Google's official test ID in debug mode, and your live ID in release builds[cite: 15].
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Official Google test banner ad ID for safe testing during development
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    // Your live AdMob Banner Ad Unit ID[cite: 15]
    return 'ca-app-pub-5323056712681249/1824201567';
  }
}