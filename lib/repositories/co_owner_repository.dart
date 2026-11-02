// lib/repositories/co_owner_repository.dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/co_owner_model.dart';

class CoOwnerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Generates a cryptographically secure Co-Owner access code.
  /// Format: ADMN-XXXXXXXX (8 random chars from a 31-char unambiguous set)
  /// Entropy: 31^8 ? 8.5 ? 10^11 combinations ? brute-force impractical.
  String _generateAccessCode() {
    // Omit visually ambiguous characters (0/O, 1/I/L) to prevent misreading.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final suffix =
        List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'ADMN-$suffix';
  }

  Future<List<CoOwnerModel>> getCoOwners(String ownerId) async {
    final data = await _client
        .from('owner_admins')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => CoOwnerModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<CoOwnerModel> createCoOwner({
    required String ownerId,
    required String name,
  }) async {
    try {
      final code = _generateAccessCode();
      final data = await _client
          .from('owner_admins')
          .insert({
        'owner_id': ownerId,
        'name': name,
        'access_code': code,
        'is_active': true,
      })
          .select()
          .single();

      return CoOwnerModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Permanently deactivates a Co-Owner (one-way: sets is_active = false, keeps record in DB)
  Future<void> deactivateCoOwner(String id) async {
    try {
      await _client
          .from('owner_admins')
          .update({'is_active': false}).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}