import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

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
                  song: playlist.getDisplaySong(),
                ),
                title: Text(
                  index == 0 ? l10n.favorites : playlist.name,
                  style: TextStyle(fontSize: 14),
                ),

                onTap: () {
                  playlist.add(widget.songList);
                  showCenterMessage(
                    context,
                    l10n.added2Playlist,
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
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor, width: 1.5),
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
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 12),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: textColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: textColor, width: 1.5),
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
    await playlistsManager.createPlaylist(result);
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

Widget reorderablePlaylistsView() {
  return ReorderableListView.builder(
    header: _playlistListTile(playlistsManager.playlists[0]),
    buildDefaultDragHandles: false,
    onReorder: (oldIndex, newIndex) {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = playlistsManager.playlists.removeAt(oldIndex + 1);
      playlistsManager.playlists.insert(newIndex + 1, item);
      playlistsManager.update();
    },
    onReorderStart: (_) {
      tryVibrate();
    },
    onReorderEnd: (_) {
      tryVibrate();
    },
    proxyDecorator: (Widget child, int index, Animation<double> animation) {
      return Material(elevation: 0.1, color: Colors.transparent, child: child);
    },
    itemCount: playlistsManager.playlists.length - 1,
    itemBuilder: (_, index) {
      final playlist = playlistsManager.getPlaylistByIndex(index + 1);
      return Row(
        key: ValueKey(index),
        children: [
          Expanded(child: _playlistListTile(playlist)),

          SizedBox(
            width: 60,
            child: ReorderableDragStartListener(
              index: index,
              child: Container(
                // must set color to make area valid
                color: Colors.transparent,
                child: Row(
                  children: [
                    SizedBox(width: 10),
                    ImageIcon(reorderImage, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
    footer: SizedBox(height: 80),
  );
}

Widget _playlistListTile(Playlist playlist) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

      leading: CoverArtWidget(
        size: 50,
        borderRadius: 5,
        song: playlist.getDisplaySong(),
      ),
      title: Text(playlist.name),
      subtitle: ValueListenableBuilder(
        valueListenable: playlist.updateNotifier,
        builder: (context, _, _) {
          return Text(
            AppLocalizations.of(context).songsCount(playlist.getTotalCount()),
          );
        },
      ),
    ),
  );
}
