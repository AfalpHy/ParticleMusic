import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/play_queue_sheet.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:text_scroll/text_scroll.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return ListenableBuilder(
          listenable: Listenable.merge([
            layersManager.backgroundChangeNotifier,
            glassColor.valueNotifier,
          ]),
          builder: (context, child) {
            return GlassContainer(
              height: 50,
              settings: LiquidGlassSettings(glassColor: glassColor.value),
              shape: LiquidRoundedSuperellipse(borderRadius: 25),
              clipBehavior: .antiAlias,
              child: child,
            );
          },
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                DynamicLyricsPageRoute(
                  pageBuilder: (_, _, _) => LyricsPageLayer(),
                ),
              );
            },

            child: Row(
              children: [
                const SizedBox(width: 15),
                Hero(
                  tag: 'cover',
                  flightShuttleBuilder:
                      (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) => FittedBox(child: toHeroContext.widget),
                  child: CoverArtWidget(
                    size: 35,
                    borderRadius: 3,
                    song: currentSong,
                  ),
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: TextScroll(
                    "${getTitle(currentSong)} - ${getArtist(currentSong)}",
                    key: ValueKey(
                      currentSong.hashCode + MediaQuery.widthOf(context),
                    ),
                    velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                    style: TextStyle(fontSize: 16),
                    intervalSpaces: 10,
                    pauseBetween: Duration(seconds: 2),
                  ),
                ),

                // Play/Pause Button
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: ValueListenableBuilder(
                      valueListenable: isPlayingNotifier,
                      builder: (_, isPlaying, _) {
                        return ImageIcon(
                          isPlaying ? pauseCircleImage : playCircleFillImage,
                          size: 25,
                        );
                      },
                    ),

                    onPressed: () {
                      tryVibrate();
                      audioHandler.togglePlay();
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: Icon(Icons.playlist_play_rounded, size: 30),
                    onPressed: () {
                      tryVibrate();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return PlayQueueSheet();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 15),
              ],
            ),
          ),
        );
      },
    );
  }
}
