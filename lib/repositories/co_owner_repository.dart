// lib/repositories/co_owner_repository.dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/co_owner_model.dart';

class CoOwnerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String _generateAccessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final suffix =
    List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
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

  Future<void> toggleCoOwnerStatus(String id, bool isActive) async {
    try {
      await _client
          .from('owner_admins')
          .update({'is_active': isActive}).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deleteCoOwner(String id) async {
    await _client.from('owner_admins').delete().eq('id', id);
  }
}