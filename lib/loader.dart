import 'dart:io';

import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/library.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class Loader {
  static Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      final keepfile = File('${appDocs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    }

    settingManager = SettingManager();
    await settingManager.loadSetting();

    navidromeClient = NavidromeClient(
      username: username,
      password: password,
      baseUrl: baseUrl,
    );

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

    layersManager.pushLayer('songs');

    loadingLibraryNotifier.value = false;
  }

  static Future<void> reload() async {
    await audioHandler.clearForReload();

    library.clear();

    playlistsManager.clear();

    artistsAlbumsManager.clear();

    history.clear();
    layersManager.clear();
    await load();
  }
}
