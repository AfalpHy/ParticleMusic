import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';

abstract class StreamClient {
  final String baseUrl;
  final String username;
  final String password;

  @protected
  late final Dio dio;

  StreamClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @protected
  List<Map<String, dynamic>>? normalize(dynamic data) {
    if (data == null) {
      return null;
    }
    return List<Map<String, dynamic>>.from(data);
  }

  Future<bool> ping();

  Future<List<Map<String, dynamic>>?> getSongs(int size, int offset);

  Future<List<Map<String, dynamic>>?> getStarredSongs();

  Future<bool> updateStarredSongs(List<String> songIds);

  Future<List<Map<String, dynamic>>?> getPlaylists();

  Future<String?> createPlaylist(String name);

  Future<bool> deletePlaylist(String playlistId);

  Future<List<Map<String, dynamic>>?> getPlaylistSongs(String playlistId);

  Future<bool> updatePlaylistSongs(String playlistId, List<String> songIds);

  String getStreamUrl(String id);

  Future<Uint8List?> getPictureBytes(String songId);

  Future<String> getLyricsById(String songId);

  Future<bool> downloadSong(String songId, String savePath);

  Future<bool> scrobble(String songId);
}

StreamClient? getStreamClient(SourceType sourceType) {
  switch (sourceType) {
    case .navidrome:
      return navidromeClient;
    case .emby:
      return embyClient;
    default:
      return null;
  }
}
