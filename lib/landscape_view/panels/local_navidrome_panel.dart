import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/landscape_view/panels/song_list_panel.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';

class LocalNavidromePanel extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final String? ranking;
  final String? recently;

  final ValueNotifier<bool> displayNavidromeNotifier;
  final List<MyAudioMetadata> localSongList;
  final List<MyAudioMetadata> navidromeSongList;

  final textController = TextEditingController();

  LocalNavidromePanel({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.ranking,
    this.recently,

    required this.displayNavidromeNotifier,
    required this.localSongList,
    required this.navidromeSongList,
  });

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
            valueListenable: displayNavidromeNotifier,
            builder: (context, value, child) {
              return SongListPanel(
                key: ValueKey(value),
                textController: textController,
                playlist: playlist,
                artist: artist,
                album: album,
                ranking: ranking,
                recently: recently,
                isNavidrome: value,

                switchCallBack:
                    localSongList.isNotEmpty && navidromeSongList.isNotEmpty
                    ? () {
                        displayNavidromeNotifier.value =
                            !displayNavidromeNotifier.value;
                        layersManager.updateBackground();
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
