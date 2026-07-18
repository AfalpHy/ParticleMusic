import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class BigHomePanel extends StatefulWidget {
  const BigHomePanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigHomePanelState();
}

class _BigHomePanelState extends State<BigHomePanel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: ListView(
        children: [
          Text(l10n.songs, style: .new(fontSize: 20)),
          _listView((index) {
            return library.songListManager.getSongList()[index];
          }, library.songListManager.getSongList().length),

          Text(l10n.artists, style: .new(fontSize: 20)),
          _listView((index) {
            return artistAlbumManager.artistList[index].getCoverSong();
          }, artistAlbumManager.artistList.length),

          Text(l10n.albums, style: .new(fontSize: 20)),
          _listView(
            (index) => artistAlbumManager.albumList[index].getCoverSong(),
            artistAlbumManager.albumList.length,
          ),

          Text(l10n.ranking, style: .new(fontSize: 20)),
          _listView(
            (index) => history.rankingSongListManager.getSongList()[index],
            history.rankingSongListManager.getSongList().length,
          ),

          Text(l10n.recently, style: .new(fontSize: 20)),
          _listView(
            (index) => history.recentlySongListManager.getSongList()[index],
            history.recentlySongListManager.getSongList().length,
          ),

          Text(l10n.playlists, style: .new(fontSize: 20)),
          _listView(
            (index) => playlistManager.playlists[index].getCoverSong(),
            playlistManager.playlists.length,
          ),
        ],
      ),
    );
  }

  Widget _listView(MyAudioMetadata? Function(int) getCoverSong, int count) {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: .horizontal,
        itemCount: min(20, count),
        separatorBuilder: (context, index) {
          return const SizedBox(width: 10);
        },
        itemBuilder: (context, index) {
          bool focus = false;
          final song = getCoverSong(index);
          return StatefulBuilder(
            builder: (context, setState) {
              return Transform.scale(
                scale: focus ? 1.0 : 0.9,
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onFocusChange: (value) {
                    setState(() {
                      focus = value;
                    });
                  },
                  onTap: () {},
                  child: Column(
                    children: [
                      CoverArtWidget(size: 240, borderRadius: 20, song: song),
                      SizedBox(
                        width: 240,
                        child: ListTile(
                          mouseCursor: SystemMouseCursors.click,
                          title: Text(
                            getTitle(song),
                            style: .new(overflow: .ellipsis),
                          ),
                          subtitle: Text(
                            '${getArtist(song)} - ${getAlbum(song)}',
                            style: .new(overflow: .ellipsis),
                          ),
                          visualDensity: .new(vertical: -4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
