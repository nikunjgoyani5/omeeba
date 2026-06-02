import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Top-level function for isolate (video download). Must be top-level or static.
Future<String?> downloadVideoInIsolate(Map<String, dynamic> params) async {
  final String url = params['url'] as String;
  final String cacheDirPath = params['cacheDirPath'] as String;
  if (url.isEmpty) return null;
  try {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final key = _urlToCacheKey(url);
      final ext = _extensionFromUrl(url);
      final file = File(p.join(cacheDirPath, '$key$ext'));
      final sink = file.openWrite();
      await response.pipe(sink);
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  } catch (_) {
    return null;
  }
}

String _urlToCacheKey(String url) {
  final encoded = base64Url.encode(utf8.encode(url));
  return encoded.replaceAll('=', '').replaceAll('/', '_').replaceAll('+', '-');
}

String _extensionFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return '.mp4';
  final path = uri.path;
  if (path.toLowerCase().endsWith('.mp4')) return '.mp4';
  if (path.toLowerCase().endsWith('.mov')) return '.mov';
  if (path.toLowerCase().endsWith('.webm')) return '.webm';
  return '.mp4';
}

/// Single entry in the cache index (path + last accessed time for LRU).
class _CachedEntry {
  final String path;
  DateTime lastAccessed;

  _CachedEntry({required this.path}) : lastAccessed = DateTime.now();

  Map<String, dynamic> toJson() => {'path': path, 'lastAccessed': lastAccessed.toIso8601String()};

  factory _CachedEntry.fromJson(Map<String, dynamic> json) => _CachedEntry(
        path: json['path'] as String,
      )
        ..lastAccessed = DateTime.tryParse(json['lastAccessed'] as String? ?? '') ?? DateTime.now();
}

/// Disk cache for zeal videos with LRU eviction (oldest-first when limit hit).
/// Not cleared on API success so offline playback works; only evicts when over [maxCachedVideos].
class ZealVideoCacheService extends GetxService {
  static const int maxCachedVideos = 10;
  static const String indexFileName = 'zeal_video_cache_index.json';

  final Map<String, _CachedEntry> _index = {};
  String? _cacheDirPath;
  bool _indexLoaded = false;
  final Set<String> _downloadsInProgress = {};

  Future<String> get cacheDirPath async {
    _cacheDirPath ??= (await getTemporaryDirectory()).path;
    return _cacheDirPath!;
  }

  Future<void> _loadIndex() async {
    if (_indexLoaded) return;
    _indexLoaded = true;
    try {
      final dir = await cacheDirPath;
      final indexFile = File(p.join(dir, indexFileName));
      if (!await indexFile.exists()) return;
      final content = await indexFile.readAsString();
      final decoded = json.decode(content) as Map<String, dynamic>?;
      if (decoded == null) return;
      _index.clear();
      for (final e in decoded.entries) {
        try {
          _index[e.key] = _CachedEntry.fromJson(Map<String, dynamic>.from(e.value as Map));
        } catch (_) {}
      }
      await _evictMissingFiles();
    } catch (_) {}
  }

  Future<void> _saveIndex() async {
    try {
      final dir = await cacheDirPath;
      final indexFile = File(p.join(dir, indexFileName));
      final map = <String, dynamic>{};
      for (final e in _index.entries) {
        map[e.key] = e.value.toJson();
      }
      await indexFile.writeAsString(json.encode(map));
    } catch (_) {}
  }

  /// Remove index entries whose file no longer exists.
  Future<void> _evictMissingFiles() async {
    final toRemove = <String>[];
    for (final e in _index.entries) {
      if (!await File(e.value.path).exists()) toRemove.add(e.key);
    }
    for (final k in toRemove) {
      _index.remove(k);
    }
    await _saveIndex();
  }

  /// Returns cached file path if available and file exists; updates lastAccessed.
  Future<String?> getCachedPath(String url) async {
    if (url.isEmpty) return null;
    await _loadIndex();
    final entry = _index[url];
    if (entry == null) return null;
    final file = File(entry.path);
    if (!await file.exists()) {
      _index.remove(url);
      await _saveIndex();
      return null;
    }
    entry.lastAccessed = DateTime.now();
    return entry.path;
  }

  /// Synchronous check (uses in-memory index only; file existence not checked).
  String? getCachedPathSync(String url) {
    if (url.isEmpty) return null;
    final entry = _index[url];
    if (entry == null) return null;
    return entry.path;
  }

  /// Preload video in background (isolate). Does nothing if already cached or download in progress.
  void preloadVideo(String? url) {
    if (url == null || url.isEmpty) return;
    if (_index.containsKey(url) || _downloadsInProgress.contains(url)) return;
    _downloadsInProgress.add(url);
    _loadIndex().then((_) async {
      if (_index.containsKey(url)) {
        _downloadsInProgress.remove(url);
        return;
      }
      final dir = await cacheDirPath;
      try {
        final path = await compute(
          downloadVideoInIsolate,
          <String, dynamic>{'url': url, 'cacheDirPath': dir},
        );
        _downloadsInProgress.remove(url);
        if (path != null && path.isNotEmpty) {
          await _addToIndex(url, path);
        }
      } catch (_) {
        _downloadsInProgress.remove(url);
      }
    });
  }

  /// Download and cache a video (e.g. when user is on this reel and not cached). Runs in isolate.
  Future<String?> getOrDownload(String url) async {
    if (url.isEmpty) return null;
    final cached = await getCachedPath(url);
    if (cached != null) return cached;
    final dir = await cacheDirPath;
    try {
      final path = await compute(
        downloadVideoInIsolate,
        <String, dynamic>{'url': url, 'cacheDirPath': dir},
      );
      if (path != null && path.isNotEmpty) {
        await _addToIndex(url, path);
        return path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _addToIndex(String url, String path) async {
    await _loadIndex();
    _index[url] = _CachedEntry(path: path);
    while (_index.length > maxCachedVideos) {
      await _evictOldest();
    }
    await _saveIndex();
  }

  Future<void> _evictOldest() async {
    if (_index.isEmpty) return;
    String? oldestUrl;
    DateTime? oldestTime;
    for (final e in _index.entries) {
      if (oldestTime == null || e.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = e.value.lastAccessed;
        oldestUrl = e.key;
      }
    }
    if (oldestUrl != null) {
      final entry = _index.remove(oldestUrl);
      if (entry != null) {
        try {
          final f = File(entry.path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      await _saveIndex();
    }
  }

  /// Clear all cached videos (e.g. for settings). Not called on API success so offline playback works.
  Future<void> clearCache() async {
    await _loadIndex();
    for (final entry in _index.values) {
      try {
        final f = File(entry.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _index.clear();
    _downloadsInProgress.clear();
    _indexLoaded = false;
    await _saveIndex();
  }
}
