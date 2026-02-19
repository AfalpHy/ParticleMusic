import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'common_widgets/cover_art_widget.dart';

class PlaylistsManager {
  late File file;
  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);

  PlaylistsManager() {
    file = File("${appSupportDir.path}/playlists.txt");
    if (!(file.existsSync())) {
      file.writeAsStringSync(jsonEncode(['Favorite']));
    }
  }

  Future<void> initAllPlaylists() async {
    List<dynamic> allPlaylists = jsonDecode(await file.readAsString());
    for (String name in allPlaylists) {
      final playlist = Playlist(
        name: name,
        file: File("${appSupportDir.path}/$name.json"),
        settingFile: File("${appSupportDir.path}/${name}_setting.json"),
      );
      playlistsManager.addPlaylist(playlist);
    }
  }

  Future<void> load() async {
    for (final playlist in playlists) {
      await playlist.load();
    }
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistsMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistsMap[playlist.name] = playlist;
  }

  void createPlaylist(String name) {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        return;
      }
    }

    addPlaylist(
      Playlist(
        name: name,
        file: File("${appSupportDir.path}/$name.json"),
        settingFile: File("${appSupportDir.path}/${name}_setting.json"),
      ),
    );

    update();
  }

  void deletePlaylist(Playlist playlist) {
    playlist.file.deleteSync();
    playlist.settingFile.deleteSync();
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    updateNotifier.value++;
  }

  void clear() {
    for (final playlist in playlists) {
      playlist.clear();
    }
  }
}

class Playlist {
  String name;
  List<MyAudioMetadata> songList = [];
  File file;
  File settingFile;
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  bool isFavorite = false;

  Playlist({
    required this.name,
    required this.file,
    required this.settingFile,
  }) {
    if (!file.existsSync()) {
      file.createSync();
    }
    if (!settingFile.existsSync()) {
      saveSetting();
    } else {
      loadSetting();
    }

    isFavorite = name == 'Favorite';
  }

  Future<void> load() async {
    final contents = await file.readAsString();
    if (contents != "") {
      List<dynamic> decoded = jsonDecode(contents);
      for (String filePath in decoded) {
        MyAudioMetadata? song = filePath2LibrarySong[filePath];
        if (song == null) {
          continue;
        }
        songList.add(song);
        if (isFavorite) {
          song.isFavoriteNotifier.value = true;
        }
      }
    }
  }

  void add(List<MyAudioMetadata> songList) {
    for (MyAudioMetadata song in songList) {
      if (this.songList.contains(song)) {
        continue;
      }
      this.songList.insert(0, song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    update();
  }

  void remove(List<MyAudioMetadata> songList) {
    for (MyAudioMetadata song in songList) {
      this.songList.remove(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }
    }
    update();
  }

  Future<void> update() async {
    await file.writeAsString(
      jsonEncode(songList.map((e) => clipFilePathIfNeed(e.filePath)).toList()),
    );
    if (!isMobile) {
      panelManager.updateBackground();
    }
    updateNotifier.value++;
  }

  void loadSetting() {
    final content = settingFile.readAsStringSync();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    sortTypeNotifier.value = json['sortType'] as int? ?? 0;
  }

  void saveSetting() {
    settingFile.writeAsStringSync(
      jsonEncode({'sortType': sortTypeNotifier.value}),
    );
  }

  MyAudioMetadata? getFirstSong() {
    if (songList.isEmpty) {
      return null;
    }
    return songList.first;
  }

  void clear() {
    songList = [];
  }
}

void toggleFavoriteState(MyAudioMetadata song) {
  final favorite = playlistsManager.playlists.first;
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}

class Add2PlaylistPanel extends StatefulWidget {
  final List<MyAudioMetadata> songList;
  const Add2PlaylistPanel({super.key, required this.songList});

  @override
  State<StatefulWidget> createState() => _Add2PlaylistPanelState();
}

class _Add2PlaylistPanelState extends State<Add2PlaylistPanel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        ListTile(
          leading: SmoothClipRRect(
            smoothness: 1,
            borderRadius: BorderRadius.circular(4),
            child: Material(
              elevation: 1,
              color: Colors.grey,
              child: ImageIcon(addImage, size: 40, color: iconColor),
            ),
          ),
          title: Text(l10n.createPlaylist, style: TextStyle(fontSize: 14)),
          onTap: () async {
            if (isMobile) {
              if (await showCreatePlaylistSheet(context)) {
                setState(() {});
              }
            } else {
              if (await showCreatePlaylistDialog(context)) {
                setState(() {});
              }
            }
          },
        ),
        SizedBox(height: 5),
        Divider(height: 1, thickness: 0.5, color: dividerColor),
        SizedBox(height: 5),
        Expanded(
          child: ListView.builder(
            itemCount: playlistsManager.playlists.length,
            itemExtent: 54,
            itemBuilder: (_, index) {
              final playlist = playlistsManager.getPlaylistByIndex(index);
              return ListTile(
                leading: CoverArtWidget(
                  size: 40,
                  borderRadius: 4,
                  song: getFirstSong(playlist.songList),
                ),
                title: Text(
                  index == 0 ? l10n.favorite : playlist.name,
                  style: TextStyle(fontSize: 14),
                ),

                onTap: () {
                  playlist.add(widget.songList);
                  showCenterMessage(
                    context,
                    l10n.added2Playlists,
                    duration: 1500,
                  );
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<bool> showCreatePlaylistSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();
  final name = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return MySheet(
        SizedBox(
          height: 250, // fixed height
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // center vertically
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(
                    selectionColor: textColor.withAlpha(50),
                    cursorColor: textColor,
                    selectionHandleColor: textColor,
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, controller.text); // close with value
                },
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Colors.white70,
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.black,

                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (name != null && name != '') {
    playlistsManager.createPlaylist(name);
    return true;
  }
  return false;
}

Future<bool> showCreatePlaylistDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Center(child: Text(l10n.createPlaylist)),
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        content: TextSelectionTheme(
          data: TextSelectionThemeData(
            selectionColor: textColor.withAlpha(50),
            cursorColor: textColor,
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: Colors.white70,
                shadowColor: Colors.black54,
                foregroundColor: Colors.black,

                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.confirm),
            ),
          ),
        ],
      );
    },
  );

  if (result != null && result != '') {
    playlistsManager.createPlaylist(result);
    return true;
  }
  return false;
}

void showAddPlaylistSheet(
  BuildContext context,
  List<MyAudioMetadata> songList,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return MySheet(Add2PlaylistPanel(songList: songList));
    },
  );
}

void showAddPlaylistDialog(
  BuildContext context,
  List<MyAudioMetadata> songList,
) async {
  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 500,
          width: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Add2PlaylistPanel(songList: songList),
          ),
        ),
      );
    },
  );
}
