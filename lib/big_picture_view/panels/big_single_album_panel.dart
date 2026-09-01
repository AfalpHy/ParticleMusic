import 'dart:ui';

import 'package:material_ui/material_ui.dart';
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
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/big_play_bar.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

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
  late final bool useCurrentSongForBgTmp;
  late final MyPicture? backgroundPictureTmp;

  List<MyAudioMetadata> currentSongList = [];

  late Color baseColor;

  final _scrollController = ScrollController();

  void updateSongList() async {
    baseColor = await computeColor(widget.album.picture);
    colorManager.updateBigPictureRelatedColors(widget.album.picture);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    useCurrentSongForBgTmp = useCurrentSongForBg;
    backgroundPictureTmp = backgroundPicture;
    useCurrentSongForBg = false;

    baseColor = widget.baseColor;

    currentSongList = widget.album.songList;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      colorManager.updateBigPictureRelatedColors(widget.album.picture);

      if (isStreamSource) {
        if (currentSongList.isEmpty) {
          await widget.album.load();
          if (!mounted) {
            return;
          }
        }
      }

      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    useCurrentSongForBg = useCurrentSongForBgTmp;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      colorManager.updateBigPictureRelatedColors(
        useCurrentSongForBg
            ? currentSongNotifier.value?.picture
            : backgroundPictureTmp,
      );
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
          CoverArtWidget(picture: widget.album.picture, color: baseColor),
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
          body: content(context),
        ),

        Positioned(
          top: isTooNarrow(context) ? getTopOffset(context) + 20 : 20,
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
          top: isTooNarrow(context) ? getTopOffset(context) + 20 : 20,
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

  Widget content(BuildContext context) {
    final panelWidth = MediaQuery.widthOf(context);
    if (isTooNarrow(context)) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(children: [...coverArtAndControls(panelWidth * 0.6)]),
          ),
          songListView(true),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                SizedBox(height: 80 + getTopOffset(context)),
                Expanded(child: songListView(false)),
              ],
            ),
          ),
          SizedBox(width: panelWidth * 0.02),
          SizedBox(
            width: panelWidth * 0.25,
            child: ListView(children: coverArtAndControls(panelWidth * 0.25)),
          ),

          SizedBox(width: panelWidth * 0.05),
        ],
      );
    }
  }

  Widget songListView(bool sliver) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
        if (sliver) {
          return SliverList.builder(
            itemCount: currentSongList.length,
            itemBuilder: (context, index) {
              return _itemBuilder(context, index, currentSong);
            },
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 30),
          itemCount: currentSongList.length,
          itemBuilder: (context, index) {
            return _itemBuilder(context, index, currentSong);
          },
        );
      },
    );
  }

  Widget _itemBuilder(
    BuildContext context,
    int index,
    MyAudioMetadata? currentSong,
  ) {
    final song = currentSongList[index];
    return Builder(
      builder: (itemContext) {
        return SizedBox(
          height: 50,
          child: Material(
            color: Colors.transparent,
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: .circular(15),
            ),
            clipBehavior: .antiAlias,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: () {
                showSongOptions(
                  context: context,
                  song: song,
                  includeGoToArtist: true,
                );
              },
              onFocusChange: (value) {
                if (value) {
                  final box = itemContext.findRenderObject() as RenderBox;
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
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: currentSong == song
                            ? ListenableBuilder(
                                listenable: Listenable.merge([
                                  isPlayingNotifier,
                                  iconColor.valueNotifier,
                                ]),
                                builder: (context, child) {
                                  return RiveAnimatedIcon(
                                    key: ValueKey(
                                      isPlayingNotifier.value.toString() +
                                          iconColor.value.toString(),
                                    ),
                                    riveIcon: .sound,
                                    width: 35,
                                    height: 35,
                                    loopAnimation: isPlayingNotifier.value,
                                    color: iconColor.value,
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
                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        getArtist(song),
                        style: .new(overflow: .ellipsis),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(formatDuration(getDuration(song))),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> coverArtAndControls(double width) {
    return [
      SizedBox(height: 120),
      Hero(
        tag: 'big${widget.album.picture.id}${widget.album.name}',
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
          picture: widget.album.picture,
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
            getSourceTypeDisplayName(AppLocalizations.of(context), sourceType),
          ),
        ],
      ),
      SizedBox(height: 10),
      Row(
        mainAxisAlignment: .center,
        children: [
          IconButton(
            onPressed: () async {
              await audioHandler.setPlayQueue(currentSongList, 1);
            },
            icon: ImageIcon(shuffleImage),
            iconSize: 30,
          ),
          IconButton(
            onPressed: () async {
              await audioHandler.setPlayQueue(currentSongList, 0);
            },
            icon: Icon(Icons.play_circle_fill_rounded),
            iconSize: 50,
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                ZoomPageRoute(
                  builder: (_) => SelectableSongListPage(
                    songList: currentSongList,
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
    ];
  }
}
