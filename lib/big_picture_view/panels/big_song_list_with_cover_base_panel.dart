import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/big_play_bar.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

abstract class BigSongListWithCoverBasePanel extends StatefulWidget {
  final Color baseColor;

  const BigSongListWithCoverBasePanel({super.key, required this.baseColor});
}

abstract class BigSongListWithCoverBasePanelState<
  T extends BigSongListWithCoverBasePanel
>
    extends State<T> {
  late final String title;
  List<MyAudioMetadata> currentSongList = [];
  late final SongListManager? songListManager;

  late Color baseColor;

  late int sourceCount;
  late SourceType sourceType;

  final _scrollController = ScrollController();

  void updateSongList() async {
    baseColor = await computeCoverArtColor(getFirstSong(currentSongList));
    colorManager.updateBigPictureRelatedColors(getFirstSong(currentSongList));
    setState(() {});
  }

  @override
  void initState() {
    useCurrentSongForBg = false;
    baseColor = widget.baseColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(getFirstSong(currentSongList));
    });
    super.initState();
  }

  @override
  void dispose() {
    useCurrentSongForBg = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(currentSongNotifier.value);
    });
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.widthOf(context);
    final panelHeight = MediaQuery.heightOf(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: .expand,
      children: [
        if (mainPageThemeNotifier.value == .vivid) ...[
          CoverArtWidget(song: getFirstSong(currentSongList), color: baseColor),
          RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: panelWidth * 0.03,
                sigmaY: panelHeight * 0.03,
              ),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                color: baseColor.withAlpha(180),
              ),
            ),
          ),
        ],

        Scaffold(
          backgroundColor: panelColor.value,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              SizedBox(height: 70),
              Row(
                children: [
                  SizedBox(width: 40),
                  Text(
                    title,
                    style: .new(
                      fontWeight: .bold,
                      fontSize: 24,
                      overflow: .ellipsis,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () async {
                      audioHandler.currentIndex = Random().nextInt(
                        currentSongList.length,
                      );
                      playModeNotifier.value = 1;
                      await audioHandler.setPlayQueue(currentSongList);
                      await audioHandler.load();
                      audioHandler.play();
                    },
                    icon: ImageIcon(shuffleImage),
                  ),
                  IconButton(
                    onPressed: () async {
                      audioHandler.currentIndex = 0;
                      playModeNotifier.value = 0;
                      await audioHandler.setPlayQueue(currentSongList);
                      await audioHandler.load();
                      audioHandler.play();
                    },
                    icon: Icon(Icons.play_arrow_rounded),
                    iconSize: 30,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        ZoomPageRoute(
                          builder: (_) => SelectableSongListPage(
                            songList: currentSongList,
                            reorderable: true,
                          ),
                        ),
                      );
                    },
                    icon: Transform.scale(
                      scale: 0.95,
                      child: ImageIcon(selectImage),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
              MyDivider(color: dividerColor, indent: 40, endIndent: 40),
              Row(
                children: [
                  SizedBox(width: 40),
                  Text(getSourceTypeName(l10n, sourceType)),

                  if (sourceCount > 1) ...[
                    SizedBox(width: 10),
                    GlassContainer(
                      settings: LiquidGlassSettings(
                        glassColor: glassColor.value,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: SmoothRectangleBorder(
                          smoothness: 1,
                          borderRadius: .circular(5),
                        ),
                        clipBehavior: .antiAlias,
                        child: InkWell(
                          onTap: () {
                            showSwitchDialogIfNeed(context, songListManager!);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Text(
                              AppLocalizations.of(context).switch_,
                              style: .new(
                                color: textColor.value,
                                fontWeight: .bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 10),
              Expanded(child: content(panelWidth)),
            ],
          ),
        ),

        Positioned(
          top: isTooNarrow(context)
              ? 50
              : isMobile
              ? 20
              : 25,
          left: 20,
          child: GlassContainer(
            settings: LiquidGlassSettings(glassColor: glassColor.value),
            shape: LiquidRoundedSuperellipse(borderRadius: 30),
            clipBehavior: .antiAlias,
            child: IconButton(
              autofocus: true,
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.arrow_back_ios_rounded),
            ),
          ),
        ),

        Positioned(
          top: isTooNarrow(context) ? 50 : 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: .center,
            children: [
              Expanded(flex: 1, child: SizedBox.shrink()),
              Expanded(flex: 8, child: Center(child: BigPlayBar())),
              Expanded(flex: 1, child: SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }

  Widget content(double panelWidth) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        SizedBox(width: 40),
        Hero(
          tag: 'big${getFirstSong(currentSongList)?.id}$title',
          flightShuttleBuilder:
              (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) => FittedBox(child: toHeroContext.widget),
          child: CoverArtWidget(
            song: getFirstSong(currentSongList),
            size: panelWidth * 0.2,
            borderRadius: panelWidth * 0.01,
          ),
        ),
        SizedBox(width: panelWidth * 0.02),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(bottom: 30, right: 40),
            itemCount: currentSongList.length,
            itemBuilder: (context, index) {
              final song = currentSongList[index];

              return Builder(
                builder: (itemContext) {
                  return Material(
                    color: Colors.transparent,
                    shape: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: .circular(15),
                    ),
                    clipBehavior: .antiAlias,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        showOptions(
                          context: context,
                          song: song,
                          includeGoToArtist: true,
                          includeGoToAlbum: true,
                        );
                      },
                      onFocusChange: (value) {
                        if (value) {
                          final box =
                              itemContext.findRenderObject() as RenderBox;
                          final viewport = RenderAbstractViewport.of(box);

                          final target =
                              viewport.getOffsetToReveal(box, 0.5).offset + 40;

                          _scrollController.animateTo(
                            target.clamp(
                              _scrollController.position.minScrollExtent,
                              _scrollController.position.maxScrollExtent,
                            ),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: 20.0),
                        child: SizedBox(
                          height: 75,
                          child: songInfo(song, index),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget songInfo(MyAudioMetadata song, int index) {
    return Row(
      children: [
        SizedBox(
          height: 60,
          width: 60,
          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, currentSong, child) {
              return Center(
                child: currentSong == song
                    ? ValueListenableBuilder(
                        valueListenable: isPlayingNotifier,
                        builder: (context, value, child) {
                          return RiveAnimatedIcon(
                            key: ValueKey(value),
                            riveIcon: .sound,
                            width: 35,
                            height: 35,
                            loopAnimation: value,
                            enableAbsorbPointer: true,
                          );
                        },
                      )
                    : Text((index + 1).toString()),
              );
            },
          ),
        ),
        CoverArtWidget(song: song, size: 60, borderRadius: 8),
        SizedBox(width: 15),

        Expanded(child: Text(getTitle(song), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 15),
        Expanded(child: Text(getArtist(song), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 15),
        Expanded(child: Text(getAlbum(song), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 15),

        Text(
          formatDuration(getDuration(song)),

          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
