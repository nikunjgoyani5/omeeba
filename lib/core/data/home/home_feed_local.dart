import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/post_list_response_model.dart';
import '../../models/api_response.dart';

/// Local cache for home feed. Uses Hive; stores full [PostDataResponse] (posts + isFollowing) and pagination.
class HomeFeedLocal {
  static const String _boxName = 'home_feed';
  static const String _keyData = 'data';
  static const String _keyPagination = 'pagination';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<({PostDataResponse? data, Pagination? pagination})> getCachedFeed() async {
    final box = await _getBox();
    final dataJson = box.get(_keyData);
    final paginationJson = box.get(_keyPagination);
    if (dataJson == null || dataJson.isEmpty) return (data: null, pagination: null);
    try {
      final map = jsonDecode(dataJson) as Map<String, dynamic>;
      final data = PostDataResponse.fromJson(map);
      Pagination? pagination;
      if (paginationJson != null && paginationJson.isNotEmpty) {
        pagination = Pagination.fromJson(jsonDecode(paginationJson) as Map<String, dynamic>);
      }
      return (data: data, pagination: pagination);
    } catch (_) {
      return (data: null, pagination: null);
    }
  }

  Future<void> saveFeed({required PostDataResponse data, Pagination? pagination}) async {
    final box = await _getBox();
    await box.put(_keyData, jsonEncode(data.toJson()));
    if (pagination != null) {
      await box.put(_keyPagination, jsonEncode(pagination.toJson()));
    } else {
      await box.delete(_keyPagination);
    }
  }

  Future<void> appendFeed({required List<PostData> newPosts, Pagination? pagination}) async {
    final current = await getCachedFeed();
    final merged = PostDataResponse(
      posts: [...(current.data?.posts ?? []), ...newPosts],
      isFollowing: current.data?.isFollowing,
    );
    await saveFeed(data: merged, pagination: pagination);
  }

  /// Clear cache (e.g. on logout).
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
  }
}
