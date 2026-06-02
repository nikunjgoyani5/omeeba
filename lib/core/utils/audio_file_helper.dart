import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omeeba_new/core/utils/app_constant.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:path_provider/path_provider.dart';

/// Ensures a path usable by native audio players ([audio_waveforms]).
/// Remote URLs are downloaded once and cached under the temp directory.
class AudioFileHelper {
  AudioFileHelper._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 180),
      followRedirects: true,
      maxRedirects: 10,
      // Do not throw on 4xx — we handle status in callers.
      validateStatus: (status) => status != null && status < 500,
      headers: <String, dynamic>{
        'Accept': '*/*',
        'User-Agent': 'OmeebaFlutter/1.0',
      },
    ),
  );

  /// Only send the app JWT to Omeeba hosts. Third-party CDNs (e.g. Google Storage)
  /// reject `Authorization: Bearer <appToken>` with 401.
  static bool _shouldAttachAuthForUrl(String url) {
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (host.isEmpty) return false;
      if (host.endsWith('omeeba.co.in')) return true;
      final apiHost = Uri.parse(baseUrl).host.toLowerCase();
      return host == apiHost || host.endsWith('.$apiHost');
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _requestHeadersForUrl(String url) {
    final h = <String, String>{
      'Accept': '*/*',
      'User-Agent': 'OmeebaFlutter/1.0',
    };
    if (_shouldAttachAuthForUrl(url)) {
      final token = PrefService.getString(PrefKeys.accessToken);
      if (token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  /// Returns true if bytes look like MP3/M4A/AAC start, not HTML/JSON error body.
  static bool _looksLikeAudioBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    // ID3
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    // MPEG frame sync
    if (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0) return true;
    // Ogg
    if (bytes[0] == 0x4f && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) {
      return true;
    }
    // MP4/M4A ftyp (bytes 4–8 often "ftyp")
    if (bytes.length >= 12) {
      final s = String.fromCharCodes(bytes.sublist(4, 8));
      if (s == 'ftyp') return true;
    }
    // Reject obvious HTML / JSON error pages
    final head = String.fromCharCodes(bytes.take(64).toList());
    final t = head.trimLeft();
    if (t.startsWith('<!') || t.toLowerCase().startsWith('<html')) {
      return false;
    }
    if (t.startsWith('{') || t.startsWith('[')) {
      return false;
    }
    // Large binary payloads that are not HTML/JSON are likely audio
    if (bytes.length > 2048) {
      return true;
    }
    // Unknown small payload — reject (often 404 HTML pages)
    return false;
  }

  static String _extensionForUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      final dot = path.lastIndexOf('.');
      if (dot != -1 && dot < path.length - 1) {
        final ext = path.substring(dot).toLowerCase();
        if (ext.length <= 8) return ext;
      }
    } catch (_) {}
    return '.mp3';
  }

  static Future<File?> _writeAndValidate(File file, List<int> bytes) async {
    if (bytes.isEmpty) return null;
    if (!_looksLikeAudioBytes(bytes)) {
      debugPrint('AudioFileHelper: response does not look like audio (${bytes.length} bytes)');
      return null;
    }
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) return null;
    return file;
  }

  static Future<File?> _downloadWithHttp(String url, File file) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    final client = http.Client();
    try {
      final response = await client
          .get(uri, headers: _requestHeadersForUrl(url))
          .timeout(const Duration(seconds: 180));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode != 404 && response.statusCode != 401) {
          debugPrint('AudioFileHelper: HTTP ${response.statusCode} for $url');
        }
        return null;
      }
      return await _writeAndValidate(file, response.bodyBytes);
    } catch (e, st) {
      debugPrint('AudioFileHelper: http error: $e\n$st');
      return null;
    } finally {
      client.close();
    }
  }

  static Future<File?> _downloadWithDio(String url, File file) async {
    try {
      final response = await _dio.download(
        url,
        file.path,
        options: Options(
          headers: _requestHeadersForUrl(url),
          validateStatus: (_) => true,
        ),
        deleteOnError: true,
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        if (code != 404 && code != 401) {
          debugPrint('AudioFileHelper: Dio status $code for $url');
        }
        return null;
      }
      if (!await file.exists() || await file.length() == 0) return null;
      final bytes = await file.readAsBytes();
      if (!_looksLikeAudioBytes(bytes)) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      return file;
    } catch (e) {
      debugPrint('AudioFileHelper: dio error: $e');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Returns a local [File] for [urlOrPath], or null on failure.
  static Future<File?> ensureLocalAudioFile(String urlOrPath) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final dir = await getTemporaryDirectory();
      final safe = '${trimmed.hashCode.abs()}_${trimmed.length}';
      final ext = _extensionForUrl(trimmed);
      final file = File('${dir.path}/omeeba_music_$safe$ext');

      try {
        if (await file.exists() && await file.length() > 0) {
          final existing = await file.readAsBytes();
          if (_looksLikeAudioBytes(existing)) {
            return file;
          }
          try {
            await file.delete();
          } catch (_) {}
        }

        // Prefer http.Client — fewer edge cases than raw Dio for arbitrary URLs.
        File? result = await _downloadWithHttp(trimmed, file);
        if (result != null) return result;

        // Retry once after a short delay (transient network).
        await Future<void>.delayed(const Duration(milliseconds: 400));
        result = await _downloadWithHttp(trimmed, file);
        if (result != null) return result;

        // Fallback: Dio (handles some servers differently).
        result = await _downloadWithDio(trimmed, file);
        if (result != null) return result;

        await Future<void>.delayed(const Duration(milliseconds: 400));
        return await _downloadWithDio(trimmed, file);
      } catch (e, st) {
        debugPrint('AudioFileHelper: ensureLocalAudioFile error: $e\n$st');
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        return null;
      }
    }

    final f = File(trimmed);
    if (await f.exists()) return f;
    return null;
  }
}
