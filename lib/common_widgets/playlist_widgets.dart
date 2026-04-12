import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
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

    final specificTextColor = colorManager.getSpecificTextColor();

    return Column(
      children: [
        ListTile(
          leading: SmoothClipRRect(
            smoothness: 1,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: Colors.white30,
              child: ImageIcon(
                addImage,
                size: 40,
                color: colorManager.getSpecificIconColor(),
              ),
            ),
          ),
          title: Text(
            l10n.createPlaylist,
            style: TextStyle(fontSize: 14, color: specificTextColor),
          ),
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
        Divider(
          height: 1,
          thickness: 0.5,
          color: colorManager.getSpecificDividerColor(),
        ),
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
                  style: TextStyle(fontSize: 14, color: specificTextColor),
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
  final controller = TextEditingController();
  final name = await showTextFieldSheet(
    context,
    controller,
    needConfirmButton: true,
  );
  if (name != '') {
    playlistsManager.createPlaylist(name);
    return true;
  }
  return false;
}

Future<bool> showCreatePlaylistDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();
  final specificTextcolor = colorManager.getSpecificTextColor();

  final result = await showAnimationDialog<String>(
    context: context,
    child: SizedBox(
      width: 300,
      height: 200,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
        child: Column(
          children: [
            Center(
              child: Text(
                l10n.createPlaylist,
                style: TextStyle(fontSize: 25, color: specificTextcolor),
              ),
            ),
            SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: specificTextcolor.withAlpha(50),
                  cursorColor: specificTextcolor,
                  selectionHandleColor: specificTextcolor,
                ),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: 12, color: specificTextcolor),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: specificTextcolor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: specificTextcolor,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorManager.getSpecificButtonColor(),
                  foregroundColor: specificTextcolor,
                ),
                child: Text(l10n.confirm),
              ),
            ),
          ],
        ),
      ),
    ),
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
      return MySheet(
        Column(
          children: [
            SizedBox(height: 5),
            Expanded(child: Add2PlaylistPanel(songList: songList)),
          ],
        ),
      );
    },
  );
}

void showAddPlaylistDialog(
  BuildContext context,
  List<MyAudioMetadata> songList,
) async {
  await showAnimationDialog(
    context: context,
    child: SizedBox(
      height: 500,
      width: 400,

      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Add2PlaylistPanel(songList: songList),
      ),
    ),
  );
}

Widget reorderablePlaylistsView(BuildContext context) {
  return ReorderableListView.builder(
    header: MediaQuery.removePadding(
      context: context,
      removeLeft: true, // for mobile
      removeRight: true,
      child: _playlistListTile(playlistsManager.playlists[0]),
    ),
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
    itemBuilder: (context, index) {
      final playlist = playlistsManager.getPlaylistByIndex(index + 1);
      return MediaQuery.removePadding(
        key: ValueKey(index),
        context: context,
        removeLeft: true, // for mobile
        removeRight: true,
        child: Row(
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
        ),
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
            AppLocalizations.of(context).songCount(playlist.getTotalCount()),
          );
        },
      ),
    ),
  );
}
