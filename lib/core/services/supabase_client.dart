// lib/core/services/supabase_client.dart
// ─────────────────────────────────────────────────────────────
// Global Supabase client accessor
// Import this file in all repositories:
// import '../core/services/supabase_client.dart';
// ─────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client — use anywhere in the app
final supabase = Supabase.instance.client;
