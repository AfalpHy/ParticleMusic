import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:particle_music/common.dart';

late String username;
late String password;
late String baseUrl;

late NavidromeClient navidromeClient;

class NavidromeClient {
  final Dio dio;
  final String username;
  final String password;
  final String baseUrl;

  NavidromeClient({
    required this.username,
    required this.password,
    required this.baseUrl,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 3),
           receiveTimeout: const Duration(seconds: 5),
         ),
       );

  String _randomSalt() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(36).toRadixString(36)).join();
  }

  Map<String, String> _buildParams() {
    final salt = _randomSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();

    return {
      'u': username,
      't': token,
      's': salt,
      'v': '1.16.1',
      'c': 'Particle Music',
      'f': 'json',
    };
  }

  Map<String, dynamic> _params([Map<String, dynamic>? extra]) {
    return {..._buildParams(), ...?extra};
  }

  bool _ok(dynamic data) {
    final res = data['subsonic-response'];
    if (res['status'] != 'ok') {
      logger.output(res['error']?['message'] ?? 'Unknown error');
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _normalize(dynamic data) {
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    return [];
  }

  Future<T?> _safeRequest<T>(
    Future<Response> Function() request,
    T Function(dynamic data) parser,
  ) async {
    try {
      final res = await request();

      if (!_ok(res.data)) return null;

      return parser(res.data);
    } on DioException catch (e) {
      logger.output('Network error: ${e.message}');
      return null;
    } catch (e) {
      logger.output('Unknown error: $e');
      return null;
    }
  }

  Future<bool> ping() async {
    final res = await _safeRequest(
      () => dio.get('/rest/ping.view', queryParameters: _params()),
      (_) => true,
    );
    return res ?? false;
  }

  Future<List<Map<String, dynamic>>> getSongs() async {
    final List<Map<String, dynamic>> allSongs = [];

    int offset = 0;
    const int limit = 500;

    while (true) {
      final res = await _safeRequest(
        () => dio.get(
          '/rest/search3.view',
          queryParameters: _params({
            'query': '',
            'songCount': limit,
            'songOffset': offset,
          }),
        ),
        (data) => data,
      );

      if (res == null) break;

      final songs = res['subsonic-response']['searchResult3']['song'];

      final normalized = _normalize(songs);

      if (normalized.isEmpty) break;

      allSongs.addAll(normalized);

      offset += limit;

      logger.output('Fetched ${allSongs.length} songs...');
    }

    return allSongs;
  }

  Future<List<String>> getFavoriteSongIds() async {
    return await _safeRequest(
          () => dio.get('/rest/getStarred2.view', queryParameters: _params()),
          (data) {
            final songs = _normalize(
              data['subsonic-response']['starred2']['song'],
            );
            return songs.map((e) => e['id'] as String).toList();
          },
        ) ??
        [];
  }

  Future<bool> starSongs(List<String> songIds) async {
    final res = await _safeRequest(
      () =>
          dio.get('/rest/star.view', queryParameters: _params({'id': songIds})),
      (_) => true,
    );

    return res ?? false;
  }

  Future<bool> unstarAllSongs() async {
    final starredIds = await getFavoriteSongIds();
    final res = await _safeRequest(
      () => dio.get(
        '/rest/unstar.view',
        queryParameters: _params({'id': starredIds}),
      ),
      (_) => true,
    );

    return res ?? false;
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    return await _safeRequest(
          () => dio.get('/rest/getPlaylists.view', queryParameters: _params()),
          (data) =>
              _normalize(data['subsonic-response']['playlists']['playlist']),
        ) ??
        [];
  }

  Future<List<String>> getPlaylistSongIds(String id) async {
    return await _safeRequest(
          () => dio.get(
            '/rest/getPlaylist.view',
            queryParameters: _params({'id': id}),
          ),
          (data) {
            final entries = _normalize(
              data['subsonic-response']['playlist']['entry'],
            );
            return entries.map((e) => e['id'] as String).toList();
          },
        ) ??
        [];
  }

  Future<String?> createPlaylistAndGetId(String name) async {
    return await _safeRequest(
      () => dio.get(
        '/rest/createPlaylist.view',
        queryParameters: _params({'name': name}),
      ),
      (data) => data['subsonic-response']['playlist']['id'],
    );
  }

  Future<bool> deletePlaylist(String playlistId) async {
    final res = await _safeRequest(
      () => dio.get(
        '/rest/deletePlaylist.view',
        queryParameters: _params({'id': playlistId}),
      ),
      (_) => true,
    );

    return res ?? false;
  }

  Future<bool> addSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    final res = await _safeRequest(
      () => dio.get(
        '/rest/updatePlaylist.view',
        queryParameters: _params({
          'playlistId': playlistId,
          'songIdToAdd': songIds,
        }),
      ),
      (_) => true,
    );

    return res ?? false;
  }

  String getStreamUrl(String id) {
    return Uri.parse(
      '$baseUrl/rest/stream.view',
    ).replace(queryParameters: _params({'id': id})).toString();
  }

  Future<Uint8List?> getPictureBytes(String id) async {
    try {
      final res = await dio.get(
        '/rest/getCoverArt.view',
        queryParameters: _params({'id': id}),
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data;
    } catch (e) {
      logger.output('Cover load failed: $e');
      return null;
    }
  }
}
