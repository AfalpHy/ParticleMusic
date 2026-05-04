import 'dart:convert';
import 'dart:io';

import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/library.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class Loader {
  static Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      await BookmarkService.init();
    }

    _handleLegacyVersionData();

    settingManager = SettingManager();
    await settingManager.loadSetting();

    colorManager = ColorManager();
    colorManager.loadCustomColors();

    navidromeClient = NavidromeClient(
      username: username,
      password: password,
      baseUrl: baseUrl,
    );

    if (webdavBaseUrl != '') {
      webdavClient = webdav.newClient(
        user: webdavUsername,
        password: webdavPassword,
        webdavBaseUrl,
      );
    }

    library = Library();
    await library.initAllFolders();

    playlistsManager = PlaylistsManager();
    await playlistsManager.initAllPlaylists();

    audioHandler.initStateFiles();
  }

  static Future<void> load() async {
    loadingLibraryNotifier.value = true;
    loadingNavidromeNotifier.value = false;
    loadedCountNotifier.value = 0;

    await library.load();

    artistsAlbumsManager.load();

    await history.load();

    await playlistsManager.load();

    await audioHandler.loadPlayQueueState();
    await audioHandler.loadPlayState();
    await audioHandler.loadEqualizerState();

    await layersManager.pushLayer('songs');

    loadingLibraryNotifier.value = false;
  }

  static Future<void> reload() async {
    library.clear();

    playlistsManager.clear();

    artistsAlbumsManager.clear();

    history.clear();
    layersManager.clear();

    await audioHandler.clearForReload();

    await load();
  }

  static void _handleLegacyVersionData() {
    File tmp = File('${appSupportDir.path}/version.json');
    if (tmp.existsSync()) {
      return;
    } else {
      tmp.writeAsStringSync(jsonEncode(versionNumber));
    }

    tmp = File('${appSupportDir.path}/setting.txt');
    if (tmp.existsSync()) {
      tmp.renameSync('${appSupportDir.path}/setting.json');
    }

    tmp = File('${appSupportDir.path}/song_file_path_list.txt');
    if (tmp.existsSync()) {
      tmp.renameSync("${appSupportDir.path}/song_id_list.json");
    }

    tmp = File('${appSupportDir.path}/song_metadata_list.txt');
    if (tmp.existsSync()) {
      tmp.deleteSync();
    }

    tmp = File('${appSupportDir.path}/play_queue_state.txt');
    if (tmp.existsSync()) {
      tmp.deleteSync();
    }

    tmp = File('${appSupportDir.path}/play_state.txt');
    if (tmp.existsSync()) {
      tmp.deleteSync();
    }

    tmp = File('${appSupportDir.path}/ranking.txt');
    if (tmp.existsSync()) {
      final content = tmp.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      tmp.writeAsStringSync(
        jsonEncode(
          jsonList.map((map) {
            return {'times': map['times'] as int, 'id': map['path'] as String};
          }).toList(),
        ),
      );
      tmp.renameSync('${appSupportDir.path}/ranking.json');
    }

    tmp = File('${appSupportDir.path}/recently.txt');
    if (tmp.existsSync()) {
      tmp.renameSync('${appSupportDir.path}/recently.json');
    }

    tmp = File('${appSupportDir.path}/playlists.txt');
    if (tmp.existsSync()) {
      final content = tmp.readAsStringSync();
      tmp.renameSync('${playlistConfigDir.path}/particle_music_playlists.json');

      List<dynamic> jsonList = jsonDecode(content);

      for (String name in jsonList) {
        tmp = File('${appSupportDir.path}/$name.json');
        if (tmp.existsSync()) {
          tmp.renameSync('${playlistConfigDir.path}/$name.json');
        }

        tmp = File('${appSupportDir.path}/${name}_setting.json');
        if (tmp.existsSync()) {
          tmp.renameSync('${playlistConfigDir.path}/${name}_setting.json');
        }
      }
    }

    tmp = File('${appSupportDir.path}/folder_paths.txt');
    if (tmp.existsSync()) {
      final content = tmp.readAsStringSync();
      tmp.renameSync('${folderConfigDir.path}/folder_map_list.json');
      List<dynamic> jsonList = jsonDecode(content);
      List<Map<String, dynamic>> folderMapList = [];
      for (int i = 0; i < jsonList.length; i++) {
        final id = jsonList[i];
        final uuid = Uuid();
        final songIdListPath = '${folderConfigDir.path}/${uuid.v4()}.json';
        final songMetadataListPath =
            '${folderConfigDir.path}/${uuid.v4()}.json';
        tmp = File('${appSupportDir.path}/folder_song_file_path_list_$i.txt');
        if (tmp.existsSync()) {
          tmp.deleteSync();
        }
        folderMapList.add({
          'id': id,
          'songIdListPath': Platform.isIOS
              ? songIdListPath.split('folder_config/').last
              : songIdListPath,
          'songMetadataListPath': Platform.isIOS
              ? songMetadataListPath.split('folder_config/').last
              : songMetadataListPath,
        });
      }

      tmp = File('${folderConfigDir.path}/folder_map_list.json');
      tmp.writeAsStringSync(jsonEncode(folderMapList));
    }
  }
}
