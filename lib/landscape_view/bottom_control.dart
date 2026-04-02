import 'package:flutter/material.dart';
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
    return Material(
      color: bottomColor,
      child: SizedBox(
        height: 75,
        child: Stack(
          children: [
            currentSongTile(),
            playControls(context),
            if (!isMobile) otherControls(),
          ],
        ),
      ),
    );
  }

  Widget currentSongTile() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 300,
        child: ValueListenableBuilder(
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
                title: Text(
                  getTitle(currentSong),
                  overflow: TextOverflow.ellipsis,
                ),
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
        ),
      ),
    );
  }

  Widget playControls(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: isMobile ? 0 : null,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Spacer(),
              playModeButton(25),

              skip2PreviousButton(25),

              playOrPauseButton(35),

              skip2NextButton(25),

              showPlayQueueButton(25),

              isMobile ? SizedBox(width: 10) : Spacer(),
            ],
          ),
        ),
        Positioned(
          top: isMobile ? 0 : 35,
          bottom: 0,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Spacer(),
              SizedBox(
                width: isMobile ? 300 : 400,
                child: ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (_, _, _) {
                    return SeekBar(widgetHeight: 20, seekBarHeight: 10);
                  },
                ),
              ),

              Spacer(),
            ],
          ),
        ),
      ],
    );
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
        Speaker(color: iconColor),
        Center(
          child: SizedBox(
            height: 20,
            width: 120,
            child: VolumeBar(activeColor: volumeBarColor),
          ),
        ),
        SizedBox(width: 30),
      ],
    );
  }
}
