// lib/providers/co_owner_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/co_owner_model.dart';
import '../repositories/co_owner_repository.dart';
import 'auth_provider.dart';

final coOwnerRepositoryProvider = Provider<CoOwnerRepository>((ref) {
  return CoOwnerRepository();
});

class CoOwnersState {
  final List<CoOwnerModel> coOwners;
  final bool isLoading;
  final String? error;

  const CoOwnersState({
    this.coOwners = const [],
    this.isLoading = false,
    this.error,
  });

  CoOwnersState copyWith({
    List<CoOwnerModel>? coOwners,
    bool? isLoading,
    String? error,
  }) {
    return CoOwnersState(
      coOwners: coOwners ?? this.coOwners,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CoOwnersNotifier extends StateNotifier<CoOwnersState> {
  final CoOwnerRepository _repo;
  final String _ownerId;

  CoOwnersNotifier(this._repo, this._ownerId)
      : super(const CoOwnersState(isLoading: true)) {
    if (_ownerId.isNotEmpty) {
      loadCoOwners();
    } else {
      state = const CoOwnersState(isLoading: false);
    }
  }

  Future<void> loadCoOwners() async {
    if (_ownerId.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getCoOwners(_ownerId);
      state = CoOwnersState(coOwners: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load co-owners.',
      );
    }
  }

  Future<CoOwnerModel?> createCoOwner(String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final created = await _repo.createCoOwner(
        ownerId: _ownerId,
        name: name,
      );
      state = CoOwnersState(
        coOwners: [created, ...state.coOwners],
        isLoading: false,
      );
      return created;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    }
  }

  Future<void> toggleStatus(String id, bool isActive) async {
    try {
      await _repo.toggleCoOwnerStatus(id, isActive);
      state = state.copyWith(
        coOwners: state.coOwners.map((c) {
          if (c.id == id) {
            return CoOwnerModel(
              id: c.id,
              ownerId: c.ownerId,
              name: c.name,
              accessCode: c.accessCode,
              isActive: isActive,
              lastLoginAt: c.lastLoginAt,
              createdAt: c.createdAt,
            );
          }
          return c;
        }).toList(),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(error: msg);
      rethrow;
    }
  }

  Future<void> deleteCoOwner(String id) async {
    try {
      await _repo.deleteCoOwner(id);
      state = state.copyWith(
        coOwners: state.coOwners.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove co-owner.');
    }
  }
}

final coOwnersProvider =
StateNotifierProvider<CoOwnersNotifier, CoOwnersState>((ref) {
  final ownerId = ref.watch(authProvider).owner?.id ?? '';
  return CoOwnersNotifier(ref.watch(coOwnerRepositoryProvider), ownerId);
});