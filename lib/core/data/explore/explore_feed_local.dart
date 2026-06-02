import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/api_response.dart';
import '../../models/post_list_response_model.dart';

/// Local cache for explore tabs (explore, trending, polls). Uses Hive.
/// Data shown from cache; API only when cache empty or on pull-to-refresh.
class ExploreFeedLocal {
  static const String _boxName = 'explore_feed';
  static const String _prefixExplore = 'explore';
  static const String _prefixTrending = 'trending';
  static const String _prefixPolls = 'polls';
  static const String _data = 'data';
  static const String _pagination = 'pagination';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<({PostDataResponse? data, Pagination? pagination})> _getCached(String prefix) async {
    final box = await _getBox();
    final dataJson = box.get('${prefix}_$_data');
    final paginationJson = box.get('${prefix}_$_pagination');
    if (dataJson == null || dataJson.isEmpty) return (data: null, pagination: null);
    try {
      final data = PostDataResponse.fromJson(jsonDecode(dataJson) as Map<String, dynamic>);
      Pagination? pagination;
      if (paginationJson != null && paginationJson.isNotEmpty) {
        pagination = Pagination.fromJson(jsonDecode(paginationJson) as Map<String, dynamic>);
      }
      return (data: data, pagination: pagination);
    } catch (_) {
      return (data: null, pagination: null);
    }
  }

  Future<void> _save(String prefix, {required PostDataResponse data, Pagination? pagination}) async {
    final box = await _getBox();
    await box.put('${prefix}_$_data', jsonEncode(data.toJson()));
    if (pagination != null) {
      await box.put('${prefix}_$_pagination', jsonEncode(pagination.toJson()));
    } else {
      await box.delete('${prefix}_$_pagination');
    }
  }

  Future<void> _append(String prefix, {required List<PostData> newPosts, Pagination? pagination}) async {
    final current = await _getCached(prefix);
    final merged = PostDataResponse(
      posts: [...(current.data?.posts ?? []), ...newPosts],
      isFollowing: current.data?.isFollowing,
    );
    await _save(prefix, data: merged, pagination: pagination);
  }

  Future<({PostDataResponse? data, Pagination? pagination})> getCachedExplore() => _getCached(_prefixExplore);
  Future<({PostDataResponse? data, Pagination? pagination})> getCachedTrending() => _getCached(_prefixTrending);
  Future<({PostDataResponse? data, Pagination? pagination})> getCachedPolls() => _getCached(_prefixPolls);

  Future<void> saveExplore({required PostDataResponse data, Pagination? pagination}) =>
      _save(_prefixExplore, data: data, pagination: pagination);
  Future<void> saveTrending({required PostDataResponse data, Pagination? pagination}) =>
      _save(_prefixTrending, data: data, pagination: pagination);
  Future<void> savePolls({required PostDataResponse data, Pagination? pagination}) =>
      _save(_prefixPolls, data: data, pagination: pagination);

  Future<void> appendExplore({required List<PostData> newPosts, Pagination? pagination}) =>
      _append(_prefixExplore, newPosts: newPosts, pagination: pagination);
  Future<void> appendTrending({required List<PostData> newPosts, Pagination? pagination}) =>
      _append(_prefixTrending, newPosts: newPosts, pagination: pagination);
  Future<void> appendPolls({required List<PostData> newPosts, Pagination? pagination}) =>
      _append(_prefixPolls, newPosts: newPosts, pagination: pagination);

  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
  }
}
