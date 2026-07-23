import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
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
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

bool useCurrentSongForBg = true;

class BigSingleAlbumPanel extends StatefulWidget {
  final Album album;
  final Color baseColor;
  const BigSingleAlbumPanel({
    super.key,
    required this.album,
    required this.baseColor,
  });

  @override
  State<StatefulWidget> createState() => _BigSingleAlbumPanelState();
}

class _BigSingleAlbumPanelState extends State<BigSingleAlbumPanel> {
  FocusNode currentSongNode = FocusNode();

  List<MyAudioMetadata> currentSongList = [];
  late final SongListManager songListManager;

  late Color baseColor;

  void updateSongList() async {
    currentSongList = songListManager.getSongList();
    baseColor = await computeCoverArtColor(currentSongList.first);
    setState(() {});
  }

  @override
  void initState() {
    useCurrentSongForBg = false;
    songListManager = widget.album.songListManager;
    currentSongList = songListManager.getSongList();
    baseColor = widget.baseColor;
    songListManager.sourceTypeNotifier.addListener(updateSongList);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(widget.album.getCoverSong());
    });

    super.initState();
  }

  @override
  void dispose() {
    currentSongNode.dispose();
    useCurrentSongForBg = true;
    songListManager.sourceTypeNotifier.removeListener(updateSongList);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(currentSongNotifier.value);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appWidth = MediaQuery.widthOf(context);
    final appHeight = MediaQuery.heightOf(context);

    return Stack(
      fit: .expand,
      children: [
        if (mainPageThemeNotifier.value == .vivid) ...[
          CoverArtWidget(song: currentSongList.first, color: baseColor),
          RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: appWidth * 0.03,
                sigmaY: appHeight * 0.03,
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
          body: Row(
            children: [
              Expanded(child: songListView()),
              SizedBox(width: appWidth * 0.02),
              SizedBox(
                width: appWidth * 0.25,
                child: coverArtAndControls(appWidth * 0.25),
              ),

              SizedBox(width: appWidth * 0.05),
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
          child: Material(
            color: Colors.transparent,
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: .circular(25),
            ),
            clipBehavior: .antiAlias,
            child: GlassContainer(
              settings: LiquidGlassSettings(glassColor: glassColor.value),
              child: IconButton(
                autofocus: true,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.arrow_back_ios_rounded),
              ),
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
              Expanded(
                flex: 8,
                child: Center(child: BigPlayBar(focusNode: currentSongNode)),
              ),
              Expanded(flex: 1, child: SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }

  Widget songListView() {
    return Column(
      children: [
        SizedBox(height: isMobile ? 80 : 75),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, currentSong, child) {
              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 30),
                itemExtent: 50,
                itemCount: currentSongList.length,
                itemBuilder: (_, index) {
                  final song = currentSongList[index];
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
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: 20.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Center(
                                child: currentSong == song
                                    ? ValueListenableBuilder(
                                        valueListenable: isPlayingNotifier,
                                        builder: (context, value, child) {
                                          return ExcludeFocus(
                                            child: RiveAnimatedIcon(
                                              key: ValueKey(value),
                                              riveIcon: .sound,
                                              width: 35,
                                              height: 35,
                                              loopAnimation: value,
                                            ),
                                          );
                                        },
                                      )
                                    : Text(
                                        song.track != null
                                            ? song.track.toString()
                                            : '#',
                                      ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: .centerLeft,
                                child: Text(
                                  getTitle(song),
                                  style: .new(overflow: .ellipsis),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Text(
                                getArtist(song),
                                style: .new(overflow: .ellipsis),
                              ),
                            ),
                            Text(formatDuration(getDuration(song))),
                          ],
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

  Widget coverArtAndControls(double width) {
    return ListView(
      children: [
        SizedBox(height: 120),
        Hero(
          tag: 'big${currentSongList.first.id}${widget.album.name}',
          flightShuttleBuilder:
              (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) => FittedBox(child: toHeroContext.widget),
          child: CoverArtWidget(
            size: width,
            borderRadius: width * 0.05,
            song: currentSongList.first,
          ),
        ),
        SizedBox(height: 10),
        Text(
          widget.album.name,
          textAlign: .center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        if (widget.album.year != null)
          Text(widget.album.year.toString(), textAlign: .center),

        SizedBox(height: 10),
        Row(
          mainAxisAlignment: .center,
          children: [
            Text(
              getSourceTypeName(
                AppLocalizations.of(context),
                songListManager.sourceTypeNotifier.value,
              ),
            ),
            if (songListManager.notEmptyCount > 1) ...[
              SizedBox(width: 10),
              GlassContainer(
                settings: LiquidGlassSettings(glassColor: glassColor.value),
                child: Material(
                  color: Colors.transparent,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: .circular(5),
                  ),
                  clipBehavior: .antiAlias,
                  child: InkWell(
                    onTap: () {
                      showSwitchDialogIfNeed(context, songListManager);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Text(
                        AppLocalizations.of(context).switch_,
                        style: .new(color: textColor.value, fontWeight: .bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: .center,
          children: [
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
              iconSize: 30,
            ),
            IconButton(
              onPressed: () async {
                audioHandler.currentIndex = 0;
                playModeNotifier.value = 0;
                await audioHandler.setPlayQueue(currentSongList);
                await audioHandler.load();
                audioHandler.play();
              },
              icon: Icon(Icons.play_circle_fill_rounded),
              iconSize: 50,
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  ZoomPageRoute(
                    builder: (_) => SelectableSongListPage(
                      songList: songListManager.getSongList(),
                      reorderable: false,
                    ),
                  ),
                );
              },
              icon: Transform.scale(scale: 0.95, child: ImageIcon(selectImage)),
              iconSize: 30,
            ),
          ],
        ),
      ],
    );
  }
}
