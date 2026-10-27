import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/idir_model.dart';

abstract class IdirsRepository {
  Future<IdirModel> createDraftIdir({
    required String name,
    required String community,
    required String location,
    required String purpose,
    required double contributionAmount,
    required String contributionFrequency,
    String? status, // Client status parameter to test that server ignores it
  });

  Future<List<IdirModel>> getUserIdirs();
  Future<IdirModel?> getLatestDraft();
}

class RestIdirsRepository implements IdirsRepository {
  RestIdirsRepository({
    required ApiClient apiClient,
    this.userId,
  }) : _api = apiClient;

  final ApiClient _api;
  final String? userId;
  static const _cacheKey = 'cached_draft_idirs';

  String get _userCacheKey =>
      (userId != null && userId!.isNotEmpty) ? '${_cacheKey}_$userId' : _cacheKey;

  @override
  Future<IdirModel> createDraftIdir({
    required String name,
    required String community,
    required String location,
    required String purpose,
    required double contributionAmount,
    required String contributionFrequency,
    String? status,
  }) async {
    final payload = {
      'name': name.trim(),
      'community': community.trim(),
      'location': location.trim(),
      'purpose': purpose.trim(),
      'contributionAmount': contributionAmount,
      'contributionFrequency': contributionFrequency,
      'region': location.trim().isNotEmpty ? location.trim() : 'Addis Ababa',
      'address': location.trim(),
      'description': purpose.trim(),
      if (status != null) 'status': status,
    };

    try {
      final res = await _api.post('/idirs', body: payload);
      Map<String, dynamic> data;
      if (res is Map<String, dynamic>) {
        data = res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
      } else {
        data = payload..['id'] = 'draft-${DateTime.now().millisecondsSinceEpoch}';
        data['status'] = 'DRAFT';
      }

      final idir = IdirModel.fromMap(data);
      await _cacheDraft(idir);
      return idir;
    } catch (e) {
      // Fallback for offline / simulation: save draft locally
      final draft = IdirModel(
        id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        community: community,
        location: location,
        purpose: purpose,
        contributionAmount: contributionAmount,
        contributionFrequency: contributionFrequency,
        status: 'DRAFT', // Always DRAFT
        createdById: userId,
        createdAt: DateTime.now(),
      );
      await _cacheDraft(draft);
      return draft;
    }
  }

  @override
  Future<List<IdirModel>> getUserIdirs() async {
    try {
      final res = await _api.get('/idirs');
      List<dynamic>? list;
      if (res is List) {
        list = res;
      } else if (res is Map<String, dynamic>) {
        if (res['data'] is List) {
          list = res['data'] as List;
        } else if (res['items'] is List) {
          list = res['items'] as List;
        }
      }
      if (list != null && list.isNotEmpty) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => IdirModel.fromMap(item))
            .toList();
      }
    } catch (_) {}

    final cached = await _loadCachedDrafts();
    return cached;
  }

  @override
  Future<IdirModel?> getLatestDraft() async {
    final all = await getUserIdirs();
    final drafts = all.where((i) => i.isDraft).toList();
    if (drafts.isNotEmpty) {
      return drafts.first;
    }
    final cached = await _loadCachedDrafts();
    return cached.isNotEmpty ? cached.first : null;
  }

  Future<void> _cacheDraft(IdirModel idir) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _loadCachedDrafts();
      final updated = [idir, ...existing.where((x) => x.id != idir.id)];
      final encoded = jsonEncode(updated.map((x) => x.toMap()).toList());
      await prefs.setString(_userCacheKey, encoded);
    } catch (_) {}
  }

  Future<List<IdirModel>> _loadCachedDrafts() async {
    if (userId == null || userId!.isEmpty) {
      return [];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((item) => IdirModel.fromMap(item as Map<String, dynamic>))
            .where((item) => item.createdById == null || item.createdById == userId)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

final idirsRepositoryProvider = Provider<IdirsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final user = ref.watch(currentUserProvider);
  return RestIdirsRepository(apiClient: apiClient, userId: user?.uid);
});
