import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'cover_art_widget.dart';

late PlaylistsManager playlistsManager;

class PlaylistsManager {
  final File file;
  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  PlaylistsManager(this.file) {
    if (!(file.existsSync())) {
      file.writeAsStringSync(jsonEncode(['Favorite']));
    }
  }

  Future<List<dynamic>> getAllPlaylists() async {
    return jsonDecode(await file.readAsString());
  }

  int length() {
    return playlists.length;
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

    File playlistFile = File("${file.parent.path}/$name.json");
    File playlistSettingFile = File("${file.parent.path}/${name}_setting.txt");
    addPlaylist(
      Playlist(
        name: name,
        file: playlistFile,
        settingFile: playlistSettingFile,
      ),
    );

    update();
  }

  void deletePlaylistByIndex(int index) {
    final playlist = playlists[index];
    playlist.file.deleteSync();
    playlistsMap.remove(playlist.name);
    playlists.removeAt(index);

    update();
  }

  void deletePlaylistByName(String name) {
    final playlist = playlistsMap[name];
    playlist?.file.deleteSync();
    playlists.remove(playlist);
    playlistsMap.remove(playlist?.name);

    update();
  }

  void deletePlaylist(Playlist playlist) {
    playlist.file.deleteSync();
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    file.writeAsString(jsonEncode(playlists.map((pl) => pl.name).toList()));
    changeNotifier.value++;
  }
}

class Playlist {
  String name;
  List<AudioMetadata> songs = [];
  File file;
  File settingFile;
  ValueNotifier<int> changeNotifier = ValueNotifier(0);
  ValueNotifier<int> sortTypeNotifire = ValueNotifier(0);

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
  }

  void add(List<AudioMetadata> songs) {
    for (AudioMetadata song in songs) {
      if (this.songs.contains(song)) {
        continue;
      }
      this.songs.insert(0, song);
      if (name == 'Favorite') {
        songIsFavorite[song]!.value = true;
      }
    }
    update();
  }

  void remove(List<AudioMetadata> songs) {
    for (AudioMetadata song in songs) {
      this.songs.remove(song);
      if (name == 'Favorite') {
        songIsFavorite[song]!.value = false;
      }
    }
    update();
  }

  void update() {
    if (Platform.isIOS) {
      int prefixLength = appDocs.path.length;
      file.writeAsStringSync(
        jsonEncode(
          songs.map((s) => s.file.path.substring(prefixLength)).toList(),
        ),
      );
    } else {
      file.writeAsStringSync(
        jsonEncode(songs.map((s) => s.file.path).toList()),
      );
    }
    changeNotifier.value++;
  }

  void loadSetting() {
    final content = settingFile.readAsStringSync();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    sortTypeNotifire.value = json['sortType'] as int? ?? 0;
  }

  void saveSetting() {
    settingFile.writeAsStringSync(
      jsonEncode({'sortType': sortTypeNotifire.value}),
    );
  }
}

Map<AudioMetadata, ValueNotifier<bool>> songIsFavorite = {};

void toggleFavoriteState(AudioMetadata song) {
  final favorite = playlistsManager.getPlaylistByName('Favorite')!;
  final isFavorite = songIsFavorite[song]!;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}

class Add2PlaylistPanel extends StatefulWidget {
  final List<AudioMetadata> songs;
  const Add2PlaylistPanel({super.key, required this.songs});

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
            child: Container(
              color: Colors.grey.shade200,
              child: ImageIcon(addImage, size: 40),
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
        Divider(height: 1, color: Colors.grey.shade300),
        SizedBox(height: 5),
        Expanded(
          child: ListView.builder(
            itemCount: playlistsManager.length(),
            itemExtent: 54,
            itemBuilder: (_, index) {
              final playlist = playlistsManager.getPlaylistByIndex(index);
              return ListTile(
                leading: CoverArtWidget(
                  size: 40,
                  borderRadius: 4,
                  source: playlist.songs.isNotEmpty
                      ? getCoverArt(playlist.songs.first)
                      : null,
                ),
                title: Text(
                  index == 0 ? l10n.favorite : playlist.name,
                  style: TextStyle(fontSize: 14),
                ),

                onTap: () {
                  for (var song in widget.songs) {
                    playlist.add([song]);
                  }
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
      return mySheet(
        SizedBox(
          height: 250, // fixed height
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // center vertically
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
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
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, controller.text); // close with value
                },
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Color.fromARGB(255, 240, 245, 250),
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
        backgroundColor: Color.fromARGB(255, 235, 240, 245),
        title: Center(child: Text(l10n.createPlaylist)),
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        content: TextField(
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
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: Color.fromARGB(255, 240, 245, 250),
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

void showAddPlaylistSheet(BuildContext context, List<AudioMetadata> songs) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return mySheet(Add2PlaylistPanel(songs: songs));
    },
  );
}

void showAddPlaylistDialog(
  BuildContext context,
  List<AudioMetadata> songs,
) async {
  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Color.fromARGB(255, 235, 240, 245),
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 500,
          width: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Add2PlaylistPanel(songs: songs),
          ),
        ),
      );
    },
  );
}
