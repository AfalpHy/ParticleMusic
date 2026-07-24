import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/buttons.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';

class BigPlayBar extends StatelessWidget {
  final FocusNode? focusNode;
  const BigPlayBar({super.key, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 700),
      child: ValueListenableBuilder(
        valueListenable: currentSongNotifier,
        builder: (_, currentSong, _) {
          return ListenableBuilder(
            listenable: Listenable.merge([currentSong?.updateNotifier]),
            builder: (context, _) {
              return GlassContainer(
                height: 50,
                settings: LiquidGlassSettings(glassColor: glassColor.value),
                shape: LiquidRoundedSuperellipse(borderRadius: 25),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        SizedBox(width: constraints.maxWidth > 450 ? 10 : 15),

                        if (constraints.maxWidth > 450) ...[
                          playModeButton(20),
                          skip2PreviousButton(20),
                          playOrPauseButton(30),
                          skip2NextButton(20),
                          showPlayQueueButton(20),
                        ],

                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: .horizontal(
                                left: .circular(10),
                                right: .circular(25),
                              ),
                            ),
                            clipBehavior: .antiAlias,
                            child: InkWell(
                              mouseCursor: SystemMouseCursors.click,
                              focusNode: focusNode,

                              onTap: () {
                                if (playQueue.isEmpty) {
                                  return;
                                }
                                Navigator.of(context, rootNavigator: true).push(
                                  DynamicLyricsPageRoute(
                                    pageBuilder: (_, _, _) => LyricsPageLayer(),
                                  ),
                                );
                              },

                              child: Row(
                                children: [
                                  SizedBox(width: 10),
                                  Hero(
                                    tag: 'cover',
                                    child: CoverArtWidget(
                                      size: 40,
                                      borderRadius: 4,
                                      song: currentSong,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: .center,
                                      crossAxisAlignment: .start,
                                      children: [
                                        Text(
                                          getTitle(currentSong),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 25),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
