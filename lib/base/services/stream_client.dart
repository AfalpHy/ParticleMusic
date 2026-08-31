import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

StreamClient? streamClient;

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

  Future<List<MyAudioMetadata>?> searchSongs(
    String query,
    int size,
    int offset,
  );

  Future<List<MyAudioMetadata>?> getSongs(int size, int offset);

  Future<List<Artist>?> getArtistList();

  Future<List<Album>?> getArtistAlbumList(String id);

  Future<List<MyAudioMetadata>?> getArtistSongs(String id);

  Future<List<Album>?> getAlbumList(int offset, {String type});

  Future<List<MyAudioMetadata>?> getAlbumSongs(String id);

  // use playlist to save playqueue(no limit)
  Future<List<MyAudioMetadata>?> getPlayQueue() async {
    if (playlistManager.playQueueForStream.id == null) {
      return null;
    }
    return getPlaylistSongs(playlistManager.playQueueForStream.id!);
  }

  Future<bool> savePlayQueue(List<String> songIds) async {
    if (playlistManager.playQueueForStream.id != null) {
      if (!await deletePlaylist(playlistManager.playQueueForStream.id!)) {
        return false;
      }
    }
    playlistManager.playQueueForStream.id = await createPlaylist(
      playlistManager.playQueueForStream.name,
    );

    return updatePlaylistSongs(playlistManager.playQueueForStream.id!, songIds);
  }

  Future<List<MyAudioMetadata>?> getStarredSongs();

  Future<bool> updateStarredSongs(List<String> songIds);

  Future<List<Playlist>?> getPlaylists();

  Future<String?> createPlaylist(String name);

  Future<bool> deletePlaylist(String playlistId);

  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId);

  Future<bool> updatePlaylistSongs(String playlistId, List<String> songIds);

  String getStreamUrl(String id);

  Future<Uint8List?> getPictureBytes(String songId);

  Future<String> getLyricsById(String songId);

  Future<bool> downloadSong(String songId, String savePath);

  Future<bool> scrobble(String songId);
}
