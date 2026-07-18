import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/network_error_reporter.dart';

EmbyClient? embyClient;

class EmbyClient {
  final String baseUrl;
  final String username;
  final String password;

  late final Dio dio;

  String? accessToken;
  String? userId;

  EmbyClient({
    required this.baseUrl,
    required this.username,
    required this.password,
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

      reportNetworkError('Emby', e.message ?? 'network error');

      return null;
    } catch (e) {
      logger.output('[Emby] Unknown error: $e');
      reportNetworkError('Emby', e.toString());
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

    return result ?? false;
  }

  Future<bool> ping() async {
    final result = await _safeRequest(
      () => dio.get('/System/Info/Public'),
      (response) => response.statusCode == 200,
    );

    return result ?? false;
  }

  /// Get all libraries
  Future<List<dynamic>> getLibraries() async {
    final result = await _safeRequest(
      () => dio.get('/Users/$userId/Views'),
      (response) => response.data['Items'] as List<dynamic>,
    );

    return result ?? [];
  }

  /// Get music libraries only
  Future<List<dynamic>> getMusicLibraries() async {
    try {
      final libraries = await getLibraries();

      return libraries.where((e) {
        return e['CollectionType'] == 'music';
      }).toList();
    } catch (e) {
      logger.output('[Emby] Get music libraries error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getAllSongs({int limit = 50}) async* {
    final libraries = await getMusicLibraries();

    if (libraries.isEmpty) {
      return;
    }

    final libraryId = libraries.first['Id'];

    int startIndex = 0;
    int cnt = 0;

    while (true) {
      final items = await _safeRequest(
        () => dio.get(
          '/Users/$userId/Items',
          queryParameters: {
            'ParentId': libraryId,
            'Recursive': true,
            'IncludeItemTypes': 'Audio',

            'StartIndex': startIndex,
            'Limit': limit,

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
        break;
      }

      yield items;

      cnt += items.length;
      startIndex += limit;

      logger.output('[Emby] Fetched $cnt songs...');
    }
  }

  /// Audio stream URL
  String audioUrl(String songId) {
    return '${dio.options.baseUrl}/Audio/$songId/stream'
        '?UserId=$userId&api_key=$accessToken&static=true';
  }

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

  Future<bool> downloadSong({
    required String itemId,
    required String savePath,
    CancelToken? cancelToken,
  }) async {
    return _boolRequest(
      () => dio.download(
        '/Items/$itemId/Download',
        savePath,
        queryParameters: {'api_key': accessToken},
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(receiveTimeout: Duration.zero),
      ),
    );
  }

  Future<List<String>> getFavoriteSongIds() async {
    final result = await _safeRequest(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
        },
      ),
      (response) {
        return (response.data['Items'] as List)
            .map((e) => e['Id'].toString())
            .toList();
      },
    );

    return result ?? [];
  }

  Future<bool> clearFavorites() async {
    try {
      final ids = await getFavoriteSongIds();

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

  Future<bool> rebuildFavorites(List<String> songIds) async {
    try {
      final cleared = await clearFavorites();

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

  Future<List<dynamic>> getPlaylists() async {
    final result = await _safeRequest(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {'IncludeItemTypes': 'Playlist', 'Recursive': true},
      ),
      (response) {
        return response.data['Items'] as List<dynamic>;
      },
    );

    return result ?? [];
  }

  Future<List<String>> getPlaylistItems(String playlistId) async {
    final result = await _safeRequest(
      () => dio.get('/Playlists/$playlistId/Items'),
      (response) {
        return (response.data['Items'] as List)
            .map((e) => e['Id'].toString())
            .toList();
      },
    );

    return result ?? [];
  }

  Future<String?> createPlaylist({
    required String name,
    required List<String> songIds,
  }) async {
    return _safeRequest(
      () => dio.post(
        '/Playlists',
        queryParameters: {
          'Name': name,
          'Ids': songIds.join(','),
          'MediaType': 'Audio',
        },
      ),
      (response) => response.data['Id']?.toString(),
    );
  }

  Future<bool> deletePlaylist(String playlistId) async {
    return _boolRequest(() => dio.delete('/Items/$playlistId'));
  }
}
