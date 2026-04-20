import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.playlists),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: playlistsManager.updateNotifier,
        builder: (context, _, _) {
          return ListView.builder(
            itemCount: playlistsManager.playlists.length + 1,
            itemBuilder: (_, index) {
              if (index == playlistsManager.playlists.length) {
                return SizedBox(height: 70);
              }
              final playlist = playlistsManager.getPlaylistByIndex(index);
              return ListTile(
                contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

                leading: ValueListenableBuilder(
                  valueListenable: playlist.updateNotifier,
                  builder: (_, _, _) {
                    return ValueListenableBuilder(
                      valueListenable: playlist.displayNavidromeNotifier,
                      builder: (context, value, child) {
                        return CoverArtWidget(
                          size: 50,
                          borderRadius: 5,
                          song: playlist.getDisplaySong(),
                        );
                      },
                    );
                  },
                ),
                title: AutoSizeText(
                  index == 0 ? l10n.favorites : playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: 15,
                  maxFontSize: 15,
                ),
                subtitle: ValueListenableBuilder(
                  valueListenable: playlist.updateNotifier,
                  builder: (_, _, _) {
                    return Text(l10n.songCount(playlist.getTotalCount()));
                  },
                ),
                onTap: () {
                  layersManager.switchLayer('_${playlist.name}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
