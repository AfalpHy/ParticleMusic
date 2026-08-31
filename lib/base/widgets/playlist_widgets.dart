import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
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

    return ListenableBuilder(
      listenable: Listenable.merge([
        lyricsPageForegroundColor.valueNotifier,
        miniViewForegroundColor.valueNotifier,
      ]),
      builder: (context, _) {
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
                if (await showCreatePlaylistDialog(context)) {
                  setState(() {});
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
                itemCount: playlistManager.playlists.length,
                itemExtent: 54,
                itemBuilder: (_, index) {
                  final playlist = playlistManager.getPlaylistByIndex(index);
                  return ListTile(
                    leading: CoverArtWidget(
                      size: 40,
                      borderRadius: 4,
                      picture: playlist.getCoverSong()?.picture,
                    ),
                    title: Text(
                      index == 0 ? l10n.favorites : playlist.name,
                      style: TextStyle(fontSize: 14, color: specificTextColor),
                    ),

                    onTap: () {
                      playlist.add(widget.songList);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<bool> showCreatePlaylistDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final result = await getInputTextDialog(context, l10n.createPlaylist);
  if (result != '') {
    await playlistManager.createPlaylist(result);
    return true;
  }
  return false;
}

void showAddPlaylistDialog(
  BuildContext context,
  List<MyAudioMetadata> songList,
) async {
  await showAnimationDialog(
    context: context,
    child: OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final shortSide = size.shortestSide;

        bool isPhone = shortSide < 600;
        return SizedBox(
          height: max(350, size.height * 0.7),
          width: isPhone ? 300 : 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Add2PlaylistPanel(songList: songList),
          ),
        );
      },
    ),
  );
}

Widget reorderablePlaylistsView(BuildContext context) {
  return ReorderableListView.builder(
    header: MediaQuery.removePadding(
      context: context,
      removeLeft: true, // for mobile
      removeRight: true,
      child: _playlistListTile(playlistManager.playlists[0]),
    ),
    buildDefaultDragHandles: false,
    onReorderItem: (oldIndex, newIndex) {
      final item = playlistManager.playlists.removeAt(oldIndex + 1);
      playlistManager.playlists.insert(newIndex + 1, item);
      playlistManager.update();
    },
    onReorderStart: (_) {
      tryVibrate();
    },
    onReorderEnd: (_) {
      tryVibrate();
    },
    proxyDecorator: (Widget child, int index, Animation<double> animation) {
      return Material(color: Colors.transparent, child: child);
    },
    itemCount: playlistManager.playlists.length - 1,
    itemBuilder: (context, index) {
      final playlist = playlistManager.getPlaylistByIndex(index + 1);
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
                      ImageIcon(reorderImage, color: iconColor.value),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
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
        picture: playlist.getCoverSong()?.picture,
      ),
      title: Text(playlist.name),
      subtitle: Builder(
        builder: (context) {
          return Text(
            AppLocalizations.of(context).songCount(playlist.totalCount),
          );
        },
      ),
    ),
  );
}
