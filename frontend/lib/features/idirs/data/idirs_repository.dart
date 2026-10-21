import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
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
  }) : _api = apiClient;

  final ApiClient _api;
  static const _cacheKey = 'cached_draft_idirs';

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
      'name': name,
      'community': community,
      'location': location,
      'purpose': purpose,
      'contributionAmount': contributionAmount,
      'contributionFrequency': contributionFrequency,
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
      if (res is Map<String, dynamic> && res['data'] is List) {
        final list = res['data'] as List;
        return list.map((item) => IdirModel.fromMap(item as Map<String, dynamic>)).toList();
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
      await prefs.setString(_cacheKey, encoded);
    } catch (_) {}
  }

  Future<List<IdirModel>> _loadCachedDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        return decoded
            .map((item) => IdirModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

final idirsRepositoryProvider = Provider<IdirsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RestIdirsRepository(apiClient: apiClient);
});
