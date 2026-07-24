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
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
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

class BigSingleArtistPanel extends StatefulWidget {
  final Artist artist;
  const BigSingleArtistPanel({super.key, required this.artist});

  @override
  State<StatefulWidget> createState() => _BigSingleArtistPanelState();
}

class _BigSingleArtistPanelState extends State<BigSingleArtistPanel> {
  late final bool useCurrentSongForBgTmp;
  late final MyAudioMetadata? backgroundSongTmp;
  final _scrollController = ScrollController();

  @override
  void initState() {
    useCurrentSongForBgTmp = useCurrentSongForBg;
    backgroundSongTmp = backgroundSong;
    useCurrentSongForBg = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(currentSongNotifier.value);
    });

    super.initState();
  }

  @override
  void dispose() {
    useCurrentSongForBg = useCurrentSongForBgTmp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(
        useCurrentSongForBg ? currentSongNotifier.value : backgroundSongTmp,
      );
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
          ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, value, child) {
              return CoverArtWidget(song: value, color: currentCoverArtColor);
            },
          ),
          ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, value, child) {
              return RepaintBoundary(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: panelWidth * 0.03,
                    sigmaY: panelHeight * 0.03,
                  ),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    color: currentCoverArtColor.withAlpha(180),
                  ),
                ),
              );
            },
          ),
        ],

        Scaffold(
          backgroundColor: panelColor.value,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              SizedBox(height: 70 + getTopOffset(context)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTooNarrow(context) ? 20 : 40,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.artist.name,
                            style: .new(
                              fontWeight: .bold,
                              fontSize: 24,
                              overflow: .ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            audioHandler.currentIndex = Random().nextInt(
                              widget.artist.songListManager
                                  .getSongList()
                                  .length,
                            );
                            playModeNotifier.value = 1;
                            await audioHandler.setPlayQueue(
                              widget.artist.songListManager.getSongList(),
                            );
                            await audioHandler.load();
                            audioHandler.play();
                          },
                          icon: ImageIcon(shuffleImage),
                        ),
                        IconButton(
                          onPressed: () async {
                            audioHandler.currentIndex = 0;
                            playModeNotifier.value = 0;
                            await audioHandler.setPlayQueue(
                              widget.artist.songListManager.getSongList(),
                            );
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
                                  songList: widget.artist.songListManager
                                      .getSongList(),
                                  reorderable: false,
                                ),
                              ),
                            );
                          },
                          icon: Transform.scale(
                            scale: 0.95,
                            child: ImageIcon(selectImage),
                          ),
                        ),
                      ],
                    ),

                    MyDivider(color: dividerColor),
                    Row(
                      children: [
                        Text(
                          '${getSourceTypeName(l10n, widget.artist.songListManager.sourceTypeNotifier.value)}: ${widget.artist.albumList.length} ${l10n.albums}, ${l10n.songCount(widget.artist.songListManager.getSongList().length)}',
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),

              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),

                    for (final album in widget.artist.albumList)
                      SliverMainAxisGroup(
                        slivers: [
                          albumContent(album, panelWidth),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: isTooNarrow(context) ? 10 : 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: getTopOffset(context) + 20,
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
          top: getTopOffset(context) + 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: .center,
            children: [
              Expanded(flex: 1, child: SizedBox.shrink()),
              Expanded(flex: 3, child: Center(child: BigPlayBar())),
              Expanded(flex: 1, child: SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }

  Widget albumContent(Album album, double panelWidth) {
    if (isTooNarrow(context)) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: CoverArtWidget(
                song: album.getCoverSong(),
                size: panelWidth * 0.6,
                borderRadius: panelWidth * 0.06,
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 10)),
          albumTitleAndSongList(album),
        ],
      );
    }
    return SliverCrossAxisGroup(
      slivers: [
        SliverConstrainedCrossAxis(
          maxExtent: 40,
          sliver: SliverToBoxAdapter(child: SizedBox()),
        ),
        SliverConstrainedCrossAxis(
          maxExtent: panelWidth * 0.2,
          sliver: SliverToBoxAdapter(
            child: CoverArtWidget(
              song: album.getCoverSong(),
              size: panelWidth * 0.2,
              borderRadius: panelWidth * 0.01,
            ),
          ),
        ),

        albumTitleAndSongList(album),
        SliverConstrainedCrossAxis(
          maxExtent: 20,
          sliver: SliverToBoxAdapter(child: SizedBox()),
        ),
      ],
    );
  }

  Widget albumTitleAndSongList(Album album) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: .symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        album.name,
                        style: .new(
                          fontWeight: .bold,
                          fontSize: 20,
                          overflow: .ellipsis,
                        ),
                      ),
                      if (album.year != null)
                        Text(
                          album.year.toString(),
                          style: .new(overflow: .ellipsis),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final songList = album.songListManager
                        .getSongList()
                        .where(
                          (song) =>
                              getArtist(song).contains(widget.artist.name),
                        )
                        .toList();
                    audioHandler.currentIndex = Random().nextInt(
                      songList.length,
                    );
                    playModeNotifier.value = 1;
                    await audioHandler.setPlayQueue(songList);
                    await audioHandler.load();
                    audioHandler.play();
                  },
                  icon: ImageIcon(shuffleImage),
                ),
                IconButton(
                  onPressed: () async {
                    final songList = album.songListManager
                        .getSongList()
                        .where(
                          (song) =>
                              getArtist(song).contains(widget.artist.name),
                        )
                        .toList();
                    audioHandler.currentIndex = 0;
                    playModeNotifier.value = 0;
                    await audioHandler.setPlayQueue(songList);
                    await audioHandler.load();
                    audioHandler.play();
                  },
                  icon: Icon(Icons.play_arrow_rounded),
                  iconSize: 30,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(color: dividerColor, indent: 20, endIndent: 20),
        ),
        SliverPadding(
          padding: .symmetric(horizontal: isTooNarrow(context) ? 0 : 10),

          sliver: SliverList.builder(
            itemCount: album.songListManager.getSongList().length,
            itemBuilder: (context, index) {
              final song = album.songListManager.getSongList()[index];
              final artist = getArtist(song);

              if (!artist.contains(widget.artist.name)) {
                return SizedBox.shrink();
              }
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
                          includeGoToArtist: artist != widget.artist.name,
                          excludedArtist: widget.artist.name,
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
                        child: songInfo(song),
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

  Widget songInfo(MyAudioMetadata song) {
    return Row(
      children: [
        SizedBox(
          height: 50,
          width: 50,
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
                    : Text(song.track != null ? song.track.toString() : '#'),
              );
            },
          ),
        ),
        Expanded(child: Text(getTitle(song), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 15),
        Expanded(child: Text(getArtist(song), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 15),
        Text(
          formatDuration(getDuration(song)),

          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
