// lib/core/constants/app_constants.dart
// ─────────────────────────────────────────────────────────────
// Central config for the entire app.
// IMPORTANT: Replace the placeholder values with your actual
// Supabase project URL and anon key from:
// Supabase Dashboard → Settings → API
// ─────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── Supabase ──────────────────────────────────────────────
  static const String supabaseUrl = 'https://ycstpyylmcggpfscrhab.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inljc3RweXlsbWNnZ3Bmc2NyaGFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MTIzNzAsImV4cCI6MjA5MzM4ODM3MH0.3yAYxm-WnkpDg7mhb3_2x533vj_q2nQaY2NHM_n_MYk';

  // ── Razorpay ──────────────────────────────────────────────
  // ⚠️  REGENERATE before launch — current key was shared publicly.
  // Switch rzp_test_ → rzp_live_ for production.
  static const String razorpayKeyId = 'rzp_test_ThMjDTWNO7te4s';
  static const String razorpayKeySecret = ''; // NEVER put secret in app

  // ── AdMob ─────────────────────────────────────────────────
  static const String admobAppIdAndroid = 'ca-app-pub-YOUR_APP_ID~XXXXXXXXXX';
  static const String admobAppIdIos = 'ca-app-pub-YOUR_APP_ID~XXXXXXXXXX';
  static const String admobBannerAndroid = 'ca-app-pub-YOUR_APP_ID/XXXXXXXXXX';
  static const String admobBannerIos = 'ca-app-pub-YOUR_APP_ID/XXXXXXXXXX';
  // Use test IDs during development:
  // Android test banner: ca-app-pub-3940256099942544/6300978111
  // iOS test banner:     ca-app-pub-3940256099942544/2934735716

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'SahiReport';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@fieldtrack.in';
  static const String deepLinkScheme = 'fieldtrack';

  // ── Free Plan Limits ──────────────────────────────────────
  // 2 projects per owner, 5 users PER PROJECT.
  // These MUST stay in sync with the DB triggers
  // (enforce_project_limit / enforce_user_limit).
  static const int freePlanMaxProjects = 2;
  static const int freePlanMaxUsersPerProject = 5;
  static const int freePlanMaxSubmissions = 50; // Per month

  // ── Pro Plan Pricing (in paise — 1 INR = 100 paise) ──────
  // ₹499 per extra project per year
  static const int proPricePerProjectPaise = 49900; // ₹499
  static const double gstRate = 0.18; // 18% (add once GST-registered)
  static const String gstHsnCode = '998314'; // SaaS services

  // ── Storage ───────────────────────────────────────────────
  static const String storageBucket = 'submission-images';
  static const int maxImageSizeKb = 5000; // 5 MB hard limit
  static const int targetCompressedKb = 200; // Target after compression
  static const int imageMaxDimension = 1920; // Max px on long edge
  static const int imageQuality = 78; // JPEG quality 0-100

  // ── Offline Queue ─────────────────────────────────────────
  static const String offlineDbName = 'fieldtrack_offline.db';
  static const int offlineDbVersion = 1;
  static const int uploadRetrySeconds = 30;
  static const int maxRetryAttempts = 10;

  // ── Pagination ────────────────────────────────────────────
  static const int submissionsPageSize = 20;
}