import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/playlists.dart';

class SinglePlaylistPanel extends StatelessWidget {
  final Playlist playlist;
  final textController = TextEditingController();

  SinglePlaylistPanel({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: TitleSearchField(
            key: ValueKey(l10n.searchSongs),
            hintText: l10n.searchSongs,
            textController: textController,
          ),
        ),

        Expanded(
          child: ValueListenableBuilder(
            valueListenable: playlist.displayNavidromeNotifier,
            builder: (context, value, child) {
              return SongListPanel(
                key: UniqueKey(),
                textController: textController,
                isNavidrome: value,
                playlist: playlist,

                switchCallBack:
                    playlist.songList.isNotEmpty &&
                        playlist.navidromeSongList.isNotEmpty
                    ? () {
                        playlist.displayNavidromeNotifier.value =
                            !playlist.displayNavidromeNotifier.value;
                        panelManager.updateBackground();
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
