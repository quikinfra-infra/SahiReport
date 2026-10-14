// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';

// Web needs explicit Firebase options; mobile reads google-services.json.
const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDae6cG_X9gl75J_H_v3s-XTsvM8rtpQfM',
  authDomain: 'myapp-123-678ec.firebaseapp.com',
  projectId: 'myapp-123-678ec',
  storageBucket: 'myapp-123-678ec.firebasestorage.app',
  messagingSenderId: '101160836263',
  appId: '1:101160836263:web:9cd05a48c7de19f1cc8f82',
  measurementId: 'G-CQY0MCJBXZ',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise Supabase
  // Wrapped to prevent network timeout crashes on mobile data
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    debugPrint('Supabase init failed (network offline): $e');
  }

  // Initialise Firebase + Notifications (all platforms).
  // Wrapped so a failure here can never block app startup.
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? _webFirebaseOptions : null,
    );
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notifications init failed (non-critical): $e');
  }

  runApp(
    const ProviderScope(
      child: SahiReportApp(),
    ),
  );
}