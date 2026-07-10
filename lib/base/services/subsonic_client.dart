import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/open_sonic_client.dart';

SubsonicClient? subsonicClient;

class SubsonicClient extends OpenSubsonicClient {
  SubsonicClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  });

  @override
  Stream<List<Map<String, dynamic>>> getSongs({int limit = 50}) async* {
    int offset = 0;
    int total = 0;

    final buffer = <Map<String, dynamic>>[];

    while (true) {
      final res = await safeRequest(
        () => get(
          '/rest/getAlbumList2.view',
          query: {'type': 'alphabeticalByName', 'size': 500, 'offset': offset},
        ),
        (data) => data,
      );

      if (res == null) {
        break;
      }

      final albums = normalize(res['subsonic-response']['albumList2']['album']);

      if (albums.isEmpty) {
        break;
      }

      for (final album in albums) {
        final albumRes = await safeRequest(
          () => get('/rest/getAlbum.view', query: {'id': album['id']}),
          (data) => data,
        );

        if (albumRes == null) {
          continue;
        }

        final songs = normalize(albumRes['subsonic-response']['album']['song']);
        for (final song in songs) {
          song['id'] = convertToClinetId(song['id']);
        }
        buffer.addAll(songs);

        while (buffer.length >= limit) {
          yield buffer.sublist(0, limit);
          buffer.removeRange(0, limit);

          total += limit;

          logger.output('[Subsonic] Fetched $total songs...');
        }
      }

      offset += albums.length;
    }

    if (buffer.isNotEmpty) {
      yield List<Map<String, dynamic>>.from(buffer);

      total += buffer.length;

      logger.output('[Subsonic] Fetched $total songs...');
    }
  }

  @override
  Future<bool> scrobble(String songId) async {
    return true;
  }

  // subsonic use integer as id, distinguish from emby
  String convertToClinetId(String id) {
    return 'subsonic$id';
  }

  String convertToServerId(String id) {
    return id.substring(8);
  }

  @override
  Future<List<String>> getFavoriteSongIds() async {
    return (await super.getFavoriteSongIds()).map(convertToClinetId).toList();
  }

  @override
  Future<bool> starSongs(List<String> songIds) async {
    songIds = songIds.map(convertToServerId).toList();
    return super.starSongs(songIds);
  }

  @override
  Future<List<String>> getPlaylistSongIds(String playlistId) async {
    return (await super.getPlaylistSongIds(
      playlistId,
    )).map(convertToClinetId).toList();
  }

  @override
  Future<bool> addSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    songIds = songIds.map(convertToServerId).toList();
    return super.addSongsToPlaylist(playlistId, songIds);
  }

  @override
  String getStreamUrl(String id) {
    return super.getStreamUrl(convertToServerId(id));
  }

  @override
  Future<Uint8List?> getPictureBytes(String id) async {
    return super.getPictureBytes(convertToServerId(id));
  }

  @override
  Future<String?> getLyricsById(String songId) async {
    final song = library.id2Song[songId];

    return safeRequest(
      () => get(
        '/rest/getLyrics.view',
        query: {'artist': song!.artist, 'title': song.title},
      ),
      (data) {
        final response = data['subsonic-response'];
        if (response == null) return '';

        final lyrics = response['lyrics'];
        if (lyrics == null) return '';

        return lyrics['value'] as String? ?? '';
      },
    );
  }

  @override
  Future<void> downloadSong({
    required String songId,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    return super.downloadSong(
      songId: convertToServerId(songId),
      savePath: savePath,
      onProgress: onProgress,
    );
  }
}
