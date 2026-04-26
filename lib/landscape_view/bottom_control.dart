import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/buttons.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/landscape_view/speaker.dart';
import 'package:particle_music/landscape_view/volume_bar.dart';
import 'package:particle_music/common_widgets/seekbar.dart';
import 'package:particle_music/utils.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: bottomColor.valueNotifier,
      builder: (context, value, child) {
        return Material(
          color: value,
          child: SizedBox(
            height: 75,
            child: Row(
              children: [
                Expanded(flex: 2, child: currentSongTile()),

                if (isMobile) ...[
                  Expanded(flex: 2, child: bottomSeekBar()),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: .end,
                      children: [...playControls(), SizedBox(width: 10)],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: .center,
                          children: playControls(),
                        ),
                        Transform.translate(
                          offset: Offset(0, -6),
                          child: bottomSeekBar(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: otherControls()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget currentSongTile() {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, _) {
        return Theme(
          data: Theme.of(context).copyWith(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: ListTile(
            leading: CoverArtWidget(
              size: 50,
              borderRadius: 5,
              song: currentSong,
            ),
            title: Text(getTitle(currentSong), overflow: TextOverflow.ellipsis),
            subtitle: currentSong != null
                ? Text(
                    "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13),
                  )
                : null,
            onTap: () {
              if (playQueue.isEmpty) {
                return;
              }
              displayLyricsPageNotifier.value = true;
            },
          ),
        );
      },
    );
  }

  Widget bottomSeekBar() {
    return SizedBox(
      width: isMobile ? 300 : 400,
      child: ValueListenableBuilder(
        valueListenable: currentSongNotifier,
        builder: (_, _, _) {
          return SeekBar(widgetHeight: 20, seekBarHeight: 10);
        },
      ),
    );
  }

  List<Widget> playControls() {
    return [
      playModeButton(25),

      skip2PreviousButton(25),

      playOrPauseButton(35),

      skip2NextButton(25),

      showPlayQueueButton(25),
    ];
  }

  Widget otherControls() {
    return Row(
      children: [
        Spacer(),
        IconButton(
          onPressed: () async {
            if (lyricsWindowVisible) {
              await lyricsWindowController!.hide();
            } else {
              await updateDesktopLyrics();
              await lyricsWindowController!.show();
            }
            lyricsWindowVisible = !lyricsWindowVisible;
          },
          icon: const ImageIcon(desktopLyricsImage, size: 25),
        ),
        ValueListenableBuilder(
          valueListenable: iconColor.valueNotifier,
          builder: (context, value, child) {
            return Speaker(color: value);
          },
        ),
        Center(
          child: SizedBox(
            height: 20,
            width: 120,
            child: ValueListenableBuilder(
              valueListenable: volumeBarColor.valueNotifier,
              builder: (context, value, child) {
                return VolumeBar(activeColor: value);
              },
            ),
          ),
        ),
        SizedBox(width: 30),
      ],
    );
  }
}
