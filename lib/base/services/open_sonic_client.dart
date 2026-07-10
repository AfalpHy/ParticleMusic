import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/services/logger.dart';

abstract class OpenSubsonicClient {
  final String baseUrl;
  final String username;
  final String password;

  late final Dio _dio;

  OpenSubsonicClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
  }

  @protected
  Dio get dio => _dio;

  Stream<List<Map<String, dynamic>>> getSongs({int limit = 50});

  Future<bool> scrobble(String songId);

  @protected
  String randomSalt() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(36).toRadixString(36)).join();
  }

  @protected
  Map<String, String> buildParams() {
    final salt = randomSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();

    return {
      'u': username,
      't': token,
      's': salt,
      'v': '1.16.1',
      'c': 'Sylvakru',
      'f': 'json',
    };
  }

  @protected
  Map<String, dynamic> params([Map<String, dynamic>? extra]) {
    return {...buildParams(), ...?extra};
  }

  @protected
  Future<Response> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: params(query), options: options);
  }

  @protected
  bool ok(dynamic data) {
    final response = data['subsonic-response'];

    if (response['status'] != 'ok') {
      logger.output(
        '[$runtimeType] ${response['error']?['message'] ?? 'Unknown error'}',
      );
      return false;
    }

    return true;
  }

  @protected
  List<Map<String, dynamic>> normalize(dynamic data) {
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }

    return [];
  }

  @protected
  Future<T?> safeRequest<T>(
    Future<Response> Function() request,
    T Function(dynamic data) parser,
  ) async {
    try {
      final res = await request();

      if (!ok(res.data)) {
        return null;
      }

      return parser(res.data);
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType] Dio: ${e.message} (${e.response?.statusCode})',
      );

      if (e.response?.data != null) {
        logger.output(e.response!.data.toString());
      }

      return null;
    } catch (e) {
      logger.output('[$runtimeType] $e');

      return null;
    }
  }

  //==========================================================================
  // Common API
  //==========================================================================

  Future<bool> ping() async {
    return await safeRequest(() => get('/rest/ping.view'), (_) => true) ??
        false;
  }

  Future<List<String>> getFavoriteSongIds() async {
    return await safeRequest(() => get('/rest/getStarred2.view'), (data) {
          final songs = normalize(
            data['subsonic-response']['starred2']['song'],
          );

          return songs.map((e) => e['id'].toString()).toList();
        }) ??
        [];
  }

  Future<bool> starSongs(List<String> songIds) async {
    return await safeRequest(
          () => get('/rest/star.view', query: {'id': songIds}),
          (_) => true,
        ) ??
        false;
  }

  Future<bool> unstarAllSongs() async {
    final ids = await getFavoriteSongIds();

    return await safeRequest(
          () => get('/rest/unstar.view', query: {'id': ids}),
          (_) => true,
        ) ??
        false;
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    return await safeRequest(
          () => get('/rest/getPlaylists.view'),
          (data) =>
              normalize(data['subsonic-response']['playlists']['playlist']),
        ) ??
        [];
  }

  Future<List<String>> getPlaylistSongIds(String playlistId) async {
    return await safeRequest(
          () => get('/rest/getPlaylist.view', query: {'id': playlistId}),
          (data) {
            final entries = normalize(
              data['subsonic-response']['playlist']['entry'],
            );

            return entries.map((e) => e['id'].toString()).toList();
          },
        ) ??
        [];
  }

  Future<String?> createPlaylistAndGetId(String name) {
    return safeRequest(
      () => get('/rest/createPlaylist.view', query: {'name': name}),
      (data) => data['subsonic-response']['playlist']['id'].toString(),
    );
  }

  Future<bool> deletePlaylist(String playlistId) async {
    return await safeRequest(
          () => get('/rest/deletePlaylist.view', query: {'id': playlistId}),
          (_) => true,
        ) ??
        false;
  }

  Future<bool> addSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    return await safeRequest(
          () => get(
            '/rest/updatePlaylist.view',
            query: {'playlistId': playlistId, 'songIdToAdd': songIds},
          ),
          (_) => true,
        ) ??
        false;
  }

  String getStreamUrl(String id) {
    return Uri.parse(baseUrl)
        .resolve('rest/stream.view')
        .replace(queryParameters: params({'id': id}))
        .toString();
  }

  Future<Uint8List?> getPictureBytes(String id) async {
    int retry = 0;

    while (retry < 3) {
      try {
        final res = await get(
          '/rest/getCoverArt.view',
          query: {'id': id},
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) =>
                status == 429 || (status != null && status < 400),
          ),
        );

        if (res.statusCode == 429) {
          retry++;

          final delay = Duration(milliseconds: retry * 200);

          logger.output('[$runtimeType] CoverArt rate limit, retry $retry');

          await Future.delayed(delay);
          continue;
        }

        return res.data;
      } catch (e) {
        retry++;

        logger.output('[$runtimeType] CoverArt: $e');

        await Future.delayed(Duration(milliseconds: retry * 200));
      }
    }

    logger.output('[$runtimeType] Failed to load cover: $id');

    return null;
  }

  Future<String?> getLyricsById(String songId) {
    return safeRequest(
      () => get('/rest/getLyricsBySongId.view', query: {'id': songId}),
      (data) {
        final response = data['subsonic-response'];

        if (response == null) {
          return '';
        }

        final lyricsList = response['lyricsList'];

        if (lyricsList != null && lyricsList['structuredLyrics'] != null) {
          final List structured = lyricsList['structuredLyrics'];

          if (structured.isNotEmpty) {
            int best = 0;
            int maxLength = 0;

            for (int i = 0; i < structured.length; i++) {
              final item = structured[i];
              final lines = item['line'];

              if (lines is List && lines.isNotEmpty) {
                final value = lines.first['value'];

                if (value is String && value.length > maxLength) {
                  best = i;
                  maxLength = value.length;
                }
              }
            }

            final List lines = structured[best]['line'] ?? [];

            final buffer = StringBuffer();

            for (final line in lines) {
              final start = line['start'] ?? 0;
              final value = line['value'] ?? '';

              final minute = (start ~/ 60000).toString().padLeft(2, '0');

              final second = ((start % 60000) ~/ 1000).toString().padLeft(
                2,
                '0',
              );

              final milli = (start % 1000).toString().padLeft(3, '0');

              buffer.writeln('[$minute:$second.$milli]$value');
            }

            return buffer.toString();
          }
        }

        final lyrics = response['lyrics'];

        if (lyrics != null) {
          return lyrics['value'] ?? '';
        }

        return '';
      },
    );
  }

  Future<void> downloadSong({
    required String songId,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    try {
      final uri = Uri.parse(baseUrl)
          .resolve('/rest/download.view')
          .replace(queryParameters: params({'id': songId}));

      await _dio.download(
        uri.toString(),
        savePath,
        onReceiveProgress: onProgress,
      );
    } on DioException catch (e) {
      logger.output('[$runtimeType] Download failed: ${e.message}');
    } catch (e) {
      logger.output('[$runtimeType] Download failed: $e');
    }
  }
}
