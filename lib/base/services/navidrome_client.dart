import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/stream_client.dart';

class NavidromeClient extends StreamClient {
  NavidromeClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

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
  Future<T?> safeRequest<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    String errorMessage = '',
    bool showRealError = false,
  }) async {
    try {
      final res = await dio.get(
        path,
        queryParameters: params(query),
        options: options,
      );

      if (options?.responseType == .bytes) {
        return res.data;
      }

      final response = res.data['subsonic-response'];

      if (response['status'] != 'ok') {
        final resErrorMessage = response['error']?['message'];
        logger.output(
          '[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]${resErrorMessage ?? 'Unknown error'}',
        );

        if (showRealError && resErrorMessage != null) {
          showCenterMessage(resErrorMessage, duration: 3000);
        }

        return null;
      }

      return response;
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]Dio: ${e.message} (${e.response?.statusCode}\n[data]${e.response?.data.toString()})',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    } catch (e) {
      logger.output(
        '[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]$e',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    }
  }

  @override
  Future<bool> ping() async {
    return await safeRequest('/rest/ping.view', showRealError: true) != null;
  }

  @override
  Future<List<Artist>?> getArtistList() async {
    final res = await safeRequest('/rest/getArtists.view');
    if (res == null) {
      return null;
    }

    final indexs = normalize(res['artists']['index']) ?? [];
    List<Artist> artistList = [];
    for (final index in indexs) {
      for (final map in normalize(index['artist']) ?? []) {
        final name = map['name'];
        artistList.add(
          Artist(name, id: map['id'], coverArtId: map['coverArt']),
        );
      }
    }

    return artistList;
  }

  @override
  Future<List<Album>?> getArtistAlbumList(String id) async {
    final res = await safeRequest('/rest/getArtist.view', query: {'id': id});

    if (res == null) {
      return null;
    }
    return (normalize(res['artist']['album']) ?? []).map((map) {
      final name = map['name'];
      final id = map['id'];
      return artistAlbumManager.albumMap.putIfAbsent(
        id,
        () => Album(name, id: id, coverArtId: map['coverArt']),
      );
    }).toList();
  }

  @override
  Future<List<MyAudioMetadata>?> getArtistSongs(String id) async {
    final res = await safeRequest('/rest/getArtist.view', query: {'id': id});

    if (res == null) {
      return null;
    }
    final albums = normalize(res['artist']['album']) ?? [];
    List<MyAudioMetadata> songs = [];
    for (final album in albums) {
      songs.addAll(await getAlbumSongs(album['id']) ?? []);
    }
    return songs;
  }

  @override
  Future<List<Album>?> getAlbumList(
    int offset, {
    String type = 'alphabeticalByName',
  }) async {
    final res = await safeRequest(
      '/rest/getAlbumList2.view',
      query: {'type': type, 'size': 500, 'offset': offset},
    );
    if (res == null) {
      return null;
    }
    final albumList = <Album>[];
    for (final map in normalize(res['albumList2']['album']) ?? []) {
      final name = map['name'];
      final id = map['id'];
      albumList.add(
        artistAlbumManager.albumMap.putIfAbsent(
          id,
          () => Album(
            name,
            id: id,
            coverArtId: map['coverArt'],
            year: map['year'],
          ),
        ),
      );
    }
    return albumList;
  }

  @override
  Future<Album?> getAlbum(String id) async {
    final albumRes = await safeRequest(
      '/rest/getAlbum.view',
      query: {'id': id},
    );

    if (albumRes == null) {
      return null;
    }

    final map = albumRes['album'];

    final name = map['name'];

    return artistAlbumManager.albumMap.putIfAbsent(
      id,
      () => Album(name, id: id, coverArtId: map['coverArt'], year: map['year']),
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getAlbumSongs(String id) async {
    final albumRes = await safeRequest(
      '/rest/getAlbum.view',
      query: {'id': id},
    );

    if (albumRes == null) {
      return null;
    }

    return (normalize(albumRes['album']['song']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  // @override
  // Future<List<MyAudioMetadata>?> getPlayQueue() async {
  //   final res = await safeRequest('/rest/getPlayQueue.view');
  //   if (res == null) {
  //     return null;
  //   }

  //   return (normalize(res['playQueue']['entry']) ?? [])
  //       .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
  //       .toList();
  // }

  // @override
  // Future<bool> savePlayQueue(List<String> songIds) async {
  //   final res = await safeRequest(
  //     '/rest/savePlayQueue.view',
  //     query: {'id': songIds},
  //   );
  //   return res == null ? false : res['status'] == 'ok';
  // }

  @override
  Future<List<MyAudioMetadata>?> searchSongs(
    String query,
    int size,
    int offset,
  ) async {
    final response = await safeRequest(
      '/rest/search3.view',
      query: {
        'query': query,
        'albumCount': 0,
        'artistCount': 0,
        'songCount': size,
        'songOffset': offset,
      },
      errorMessage: "Failed to fetch songs",
    );

    if (response == null) {
      return null;
    }

    return (normalize(response['searchResult3']['song']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  @override
  Future<List<MyAudioMetadata>?> getSongs(int size, int offset) async {
    final songs = await searchSongs('', size, offset);

    if (songs != null) {
      logger.output('[Navidrome] Fetched ${offset + songs.length} songs...');
    }

    return songs;
  }

  @override
  Future<List<MyAudioMetadata>?> getStarredSongs() async {
    final response = await safeRequest('/rest/getStarred2.view');
    if (response == null) {
      return null;
    }

    // response['starred2'] is not empty but response['starred2']['song'] sometimes is null
    return (normalize(response['starred2']['song']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    final response = await safeRequest('/rest/getStarred2.view');
    if (response == null) {
      return false;
    }

    final oldSongIds = (normalize(response['starred2']['song']) ?? [])
        .map((e) => e['id'].toString())
        .toList();

    final songToRemoveIds = [];
    for (int i = 0; i < oldSongIds.length; i++) {
      songToRemoveIds.add(oldSongIds[i]);
      if (songToRemoveIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/unstar.view',
          query: {'id': songToRemoveIds},
        );
        if (res == null) {
          return false;
        }
        songToRemoveIds.clear();
      }
    }
    if (songToRemoveIds.isNotEmpty) {
      final res = await safeRequest(
        '/rest/unstar.view',
        query: {'id': songToRemoveIds},
      );

      if (res == null) {
        return false;
      }
    }

    final songToAddIds = [];
    for (int i = songIds.length - 1; i >= 0; i--) {
      songToAddIds.add(songIds[i]);
      if (songToAddIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/star.view',
          query: {'id': songToAddIds},
        );
        if (res == null) {
          return false;
        }
        songToAddIds.clear();
      }
    }
    if (songToAddIds.isNotEmpty) {
      return await safeRequest(
            '/rest/star.view',
            query: {'id': songToAddIds},
          ) !=
          null;
    }
    return true;
  }

  @override
  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId) async {
    final response = await safeRequest(
      '/rest/getPlaylist.view',
      query: {'id': playlistId},
    );
    if (response == null) {
      return null;
    }
    return (normalize(response?['playlist']['entry']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  @override
  Future<String?> createPlaylist(String name) async {
    final response = await safeRequest(
      '/rest/createPlaylist.view',
      query: {'name': name},
    );
    return response?['playlist']['id'].toString();
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    return await safeRequest(
          '/rest/deletePlaylist.view',
          query: {'id': playlistId},
        ) !=
        null;
  }

  @override
  Future<List<Playlist>?> getPlaylists() async {
    final response = await safeRequest('/rest/getPlaylists.view');
    return (normalize(
      response?['playlists']['playlist'],
    ))?.map((e) => Playlist(name: e['name'], id: e['id'])).toList();
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    final oldSongIds = await getPlaylistSongs(playlistId);
    if (oldSongIds == null) {
      return false;
    }
    final songIndexToRemove = [];
    for (int i = oldSongIds.length - 1; i >= 0; i--) {
      songIndexToRemove.add(i);
      if (songIndexToRemove.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/updatePlaylist.view',
          query: {
            'playlistId': playlistId,
            'songIndexToRemove': songIndexToRemove,
          },
        );
        if (res == null) {
          return false;
        }
        songIndexToRemove.clear();
      }
    }
    if (songIndexToRemove.isNotEmpty) {
      final res = await safeRequest(
        '/rest/updatePlaylist.view',
        query: {
          'playlistId': playlistId,
          'songIndexToRemove': songIndexToRemove,
        },
      );

      if (res == null) {
        return false;
      }
    }

    final songToAddIds = [];
    for (int i = 0; i < songIds.length; i++) {
      songToAddIds.add(songIds[i]);
      if (songToAddIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/updatePlaylist.view',
          query: {'playlistId': playlistId, 'songIdToAdd': songToAddIds},
        );
        if (res == null) {
          return false;
        }
        songToAddIds.clear();
      }
    }
    if (songToAddIds.isNotEmpty) {
      return await safeRequest(
            '/rest/updatePlaylist.view',
            query: {'playlistId': playlistId, 'songIdToAdd': songToAddIds},
          ) !=
          null;
    }
    return true;
  }

  @override
  String getStreamUrl(String id) {
    return Uri.parse(baseUrl)
        .resolve('rest/stream.view')
        .replace(queryParameters: params({'id': id}))
        .toString();
  }

  @override
  Future<Uint8List?> getPictureBytes(String id) async {
    return safeRequest(
      '/rest/getCoverArt.view',
      query: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  @override
  Future<String> getLyricsById(String songId) async {
    final response = await safeRequest(
      '/rest/getLyricsBySongId.view',
      query: {'id': songId},
    );

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

          final second = ((start % 60000) ~/ 1000).toString().padLeft(2, '0');

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
  }

  @override
  Future<bool> downloadSong(String songId, String savePath) async {
    try {
      final streamUrl = getStreamUrl(songId);
      final response = await dio.download(streamUrl, savePath);
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.output('[$runtimeType] Download failed: ${e.message}');
      return false;
    } catch (e) {
      logger.output('[$runtimeType] Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> scrobble(String songId) async {
    return await safeRequest(
          '/rest/scrobble.view',
          query: {'id': songId},
          errorMessage: 'Failed to scrobble',
        ) !=
        null;
  }
}
