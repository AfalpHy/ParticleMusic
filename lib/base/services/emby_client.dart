import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/network_error_reporter.dart';
import 'package:sylvakru/base/services/stream_client.dart';

EmbyClient? embyClient;

class EmbyClient extends StreamClient {
  String? accessToken;
  String? userId;

  late String _libraryId;

  EmbyClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="Sylvakru", Device="Flutter", DeviceId="sylvakru", Version="1.0.0"',
        },
      ),
    );

    _applyInterceptor();
  }

  static String _normalizeBaseUrl(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }

    return url;
  }

  void _applyInterceptor() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (accessToken != null) {
            options.headers['X-Emby-Token'] = accessToken;
          }

          handler.next(options);
        },
      ),
    );
  }

  Future<T?> _safeRequest<T>(
    Future<Response> Function() request,
    T? Function(Response response) parser,
  ) async {
    try {
      final response = await request();

      return parser(response);
    } on DioException catch (e) {
      logger.output(
        '[Emby] Dio error: ${e.message} '
        '(${e.response?.statusCode})',
      );

      if (e.response?.data != null) {
        logger.output(e.response!.data.toString());
      }

      reportNetworkError('$runtimeType', 'network error');

      return null;
    } catch (e) {
      logger.output('[Emby] Unknown error: $e');

      reportNetworkError('$runtimeType', 'network error');

      return null;
    }
  }

  Future<bool> _boolRequest(Future<Response> Function() request) async {
    return await _safeRequest(request, (_) => true) ?? false;
  }

  /// Login
  Future<bool> login() async {
    final result = await _safeRequest(
      () => dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
      ),
      (response) {
        accessToken = response.data['AccessToken'];
        userId = response.data['User']['Id'];

        return true;
      },
    );
    if (result == null || !result) {
      return false;
    }
    final libraries = await _getMusicLibraries();

    if (libraries.isEmpty) {
      return false;
    }

    _libraryId = libraries.first['Id'];
    return true;
  }

  @override
  Future<bool> ping() async {
    final result = await _safeRequest(
      () => dio.get('/System/Info/Public'),
      (response) => response.statusCode == 200,
    );

    return result ?? false;
  }

  /// Get all libraries
  Future<List<dynamic>> _getLibraries() async {
    final result = await _safeRequest(
      () => dio.get('/Users/$userId/Views'),
      (response) => response.data['Items'] as List<dynamic>,
    );

    return result ?? [];
  }

  /// Get music libraries only
  Future<List<dynamic>> _getMusicLibraries() async {
    try {
      final libraries = await _getLibraries();

      return libraries.where((e) {
        return e['CollectionType'] == 'music';
      }).toList();
    } catch (e) {
      logger.output('[Emby] Get music libraries error: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> getSongs(int size, int offset) async {
    final items = await _safeRequest(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'ParentId': _libraryId,
          'Recursive': true,
          'IncludeItemTypes': 'Audio',

          'StartIndex': offset,
          'Limit': size,

          'Fields':
              'Id,Name,Album,Artists,AlbumArtist,RunTimeTicks,Genres,ProductionYear,IndexNumber,ParentIndexNumber,MediaSources,UserData',

          'EnableImages': false,
        },
      ),
      (response) {
        return (response.data['Items'] as List).cast<Map<String, dynamic>>();
      },
    );

    if (items == null || items.isEmpty) {
      return null;
    }

    logger.output('[Emby] Fetched ${offset + items.length} songs...');
    return items;
  }

  /// Audio stream URL
  @override
  String getStreamUrl(String songId) {
    return '${dio.options.baseUrl}/Audio/$songId/stream'
        '?UserId=$userId&api_key=$accessToken&static=true';
  }

  @override
  Future<Uint8List?> getPictureBytes(String itemId) async {
    return _safeRequest(
      () => dio.get<List<int>>(
        '/Items/$itemId/Images/Primary',
        options: Options(responseType: ResponseType.bytes),
      ),
      (response) {
        return Uint8List.fromList(response.data!);
      },
    );
  }

  @override
  Future<bool> downloadSong(String songId, String savePath) async {
    return _boolRequest(
      () => dio.download(
        '/Items/$songId/Download',
        savePath,
        queryParameters: {'api_key': accessToken},
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> getStarredSongs() {
    return _safeRequest(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
        },
      ),
      (response) {
        return normalize(response.data['Items']);
      },
    );
  }

  Future<bool> _clearFavorites() async {
    try {
      final ids = (await getStarredSongs())!.map((e) => e['id']).toList();

      for (final id in ids) {
        final success = await _boolRequest(
          () => dio.delete('/Users/$userId/FavoriteItems/$id'),
        );

        if (!success) {
          return false;
        }
      }

      return true;
    } catch (e) {
      logger.output('[Emby] Clear favorites error: $e');
      return false;
    }
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    try {
      final cleared = await _clearFavorites();

      if (!cleared) {
        return false;
      }

      for (final id in songIds) {
        final success = await _boolRequest(
          () => dio.post('/Users/$userId/FavoriteItems/$id'),
        );

        if (!success) {
          return false;
        }
      }

      return true;
    } catch (e) {
      logger.output('[Emby] Rebuild favorites error: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> getPlaylists() {
    return _safeRequest(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {'IncludeItemTypes': 'Playlist', 'Recursive': true},
      ),
      (response) {
        return normalize(response.data['Items']);
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>?> getPlaylistSongs(String playlistId) {
    return _safeRequest(() => dio.get('/Playlists/$playlistId/Items'), (
      response,
    ) {
      return normalize(response.data['Items']);
    });
  }

  @override
  Future<String?> createPlaylist(String name) async {
    return _safeRequest(
      () => dio.post(
        '/Playlists',
        queryParameters: {'Name': name, 'Ids': '', 'MediaType': 'Audio'},
      ),
      (response) => response.data['Id']?.toString(),
    );
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    return true;
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    return _boolRequest(() => dio.delete('/Items/$playlistId'));
  }

  @override
  Future<String> getLyricsById(String songId) {
    // TODO: implement getLyricsById
    throw UnimplementedError();
  }

  @override
  Future<bool> scrobble(String songId) {
    // TODO: implement scrobble
    throw UnimplementedError();
  }
}
