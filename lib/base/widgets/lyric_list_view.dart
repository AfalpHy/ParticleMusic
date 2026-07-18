import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

final lyricsFontSizeOffsetNotifier = ValueNotifier(0.0);
final updateLyricsNotifier = ValueNotifier(0);

class LyricsListView extends StatefulWidget {
  final bool expanded;
  final List<LyricLine> lines;
  final bool isKaraoke;
  const LyricsListView({
    super.key,
    required this.expanded,
    required this.lines,
    required this.isKaraoke,
  });

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView>
    with WidgetsBindingObserver {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);
  StreamSubscription<Duration>? positionSub;
  bool userDragging = false;
  bool userDragged = false;

  List<LyricLine> lines = [];
  bool jump = true;
  Timer? timer;

  void scroll2CurrentIndex(Duration position) async {
    // it's weird that the position is sometimes negative
    if (audioHandler.isLoading || position < Duration.zero) {
      return;
    }
    int tmp = currentIndexNotifier.value;
    int current = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (position < line.start) {
        break;
      }
      if (current == -1 || line.start > lines[current].start) {
        current = i;
      }
    }
    currentIndexNotifier.value = current;

    if (!userDragging && (tmp != current || userDragged)) {
      userDragged = false;

      if (itemScrollController.isAttached) {
        if (jump) {
          itemScrollController.jumpTo(
            index: current + 1,
            alignment: widget.expanded ? 0.25 : 0.4,
          );
        } else {
          itemScrollController.scrollTo(
            index: current + 1,
            duration: Duration(milliseconds: 300), // smooth animation
            curve: Curves.fastOutSlowIn,
            alignment: widget.expanded ? 0.25 : 0.4,
          );
        }
      }
    }
    jump = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lines = widget.lines;
    scroll2CurrentIndex(audioHandler.getPosition());
    positionSub = audioHandler.getPositionStream().listen(
      (position) => scroll2CurrentIndex(position),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening when lyrics page is closed
    positionSub?.cancel();
    positionSub = null;

    timer?.cancel();
    timer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (positionSub == null) {
          jump = true;
          scroll2CurrentIndex(audioHandler.getPosition());
          positionSub = audioHandler.getPositionStream().listen(
            (position) => scroll2CurrentIndex(position),
          );
        }
        break;
      case AppLifecycleState.paused:
        positionSub?.cancel();
        positionSub = null;
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // scrolling to current index while resizing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndexNotifier.value == -1) {
        return;
      }
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(
          index: currentIndexNotifier.value + 1,
          alignment: widget.expanded ? 0.25 : 0.4,
        );
      }
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight; // height of the parent
        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              userDragging = true;
              timer?.cancel();
              timer = null;
            } else {
              timer ??= Timer(const Duration(milliseconds: 2000), () {
                userDragging = false;
                userDragged = true;
                timer = null;
              });
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            physics: ClampingScrollPhysics(),
            itemCount: lines.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.25
                      : parentHeight * 0.4,
                );
              } else if (index == lines.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.65
                      : parentHeight * 0.45,
                );
              }
              return LyricLineWidget(
                index: index - 1,
                line: lines[index - 1],
                currentIndexNotifier: currentIndexNotifier,
                expanded: widget.expanded,
                isKaraoke: widget.isKaraoke,
              );
            },
          ),
        );
      },
    );
  }
}

/// Each lyric line listens to currentIndexNotifier
class LyricLineWidget extends StatelessWidget {
  final int index;
  final LyricLine line;
  final ValueNotifier<int> currentIndexNotifier;
  final bool expanded;
  final bool isKaraoke;

  const LyricLineWidget({
    super.key,
    required this.line,
    required this.index,
    required this.currentIndexNotifier,
    required this.expanded,
    required this.isKaraoke,
  });

  @override
  Widget build(BuildContext context) {
    double paddingHeight = 15;
    double fontSizeOffset = 0;
    if (!isMobile) {
      final pageHeight = MediaQuery.heightOf(context);
      final pageWidth = MediaQuery.widthOf(context);
      paddingHeight += (pageHeight - 700) * 0.025;
      fontSizeOffset = min(
        (pageHeight - 700) * 0.075,
        (pageWidth - 1050) * 0.025,
      ).clamp(0, double.maxFinite);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          // add 1ms offset to avoid seeking to last lyric
          audioHandler.seek(line.start + Duration(milliseconds: 1));
        },
        customBorder: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: expanded
              ? EdgeInsets.fromLTRB(25, paddingHeight, 30, paddingHeight)
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: ValueListenableBuilder(
            valueListenable: lyricsFontSizeOffsetNotifier,
            builder: (_, _, _) {
              return ValueListenableBuilder(
                valueListenable: currentIndexNotifier,
                builder: (context, currentIndex, child) {
                  final isCurrent = currentIndex == index;

                  double fontSize = 16 + lyricsFontSizeOffsetNotifier.value;

                  if (expanded) {
                    fontSize += isMobile ? 16 : 8;
                  }

                  fontSize += fontSizeOffset;

                  final textColor = viewModeNotifier.value == .mini
                      ? miniViewForegroundColor.value
                      : lyricsPageForegroundColor.value;

                  return AnimatedScale(
                    scale: isCurrent ? 1.05 : 0.95,
                    duration: Duration(milliseconds: 300),
                    alignment: expanded ? .centerLeft : .center,
                    child: Column(
                      crossAxisAlignment: expanded ? .start : .center,
                      children: [
                        if (isCurrent && isKaraoke)
                          ValueListenableBuilder(
                            valueListenable: updateLyricsNotifier,
                            builder: (context, value, child) {
                              return KaraokeText(
                                key: UniqueKey(),
                                line: line,
                                position: audioHandler.getPosition(),
                                fontSize: fontSize,
                                expanded: expanded,
                              );
                            },
                          )
                        else
                          Text(
                            line.text,
                            textAlign: expanded ? .start : .center,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: .bold,
                              color: isCurrent
                                  ? textColor
                                  : textColor.withAlpha(128),
                            ),
                          ),
                        for (final translate in line.translates)
                          Text(
                            translate,
                            textAlign: expanded ? .start : .center,
                            style: TextStyle(
                              fontSize: fontSize - (expanded ? 8 : 4),
                              fontWeight: .bold,
                              color: textColor.withAlpha(128),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class KaraokeText extends StatefulWidget {
  final LyricLine line;
  final Duration position;
  final double fontSize;
  final bool expanded;
  final bool isDesktopLyrics;

  const KaraokeText({
    super.key,
    required this.line,
    required this.position,
    required this.fontSize,
    required this.expanded,
    this.isDesktopLyrics = false,
  });

  @override
  State<KaraokeText> createState() => KaraokeTextState();
}

class KaraokeTextState extends State<KaraokeText>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;

  Duration displayPosition = Duration.zero;
  DateTime lastSyncTime = DateTime.now();

  late Color textColor;

  void _playStateListener() {
    if (isPlayingNotifier.value) {
      lastSyncTime = DateTime.now();
      if (!ticker.isActive) {
        ticker.start();
      }
    } else {
      if (ticker.isActive) {
        ticker.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    displayPosition = widget.position;
    ticker = createTicker((_) {
      final now = DateTime.now();

      setState(() {
        displayPosition += now.difference(lastSyncTime);
        lastSyncTime = now;
      });
    });

    isPlayingNotifier.addListener(_playStateListener);

    if (isPlayingNotifier.value) {
      ticker.start();
    }

    textColor = widget.isDesktopLyrics
        ? Colors.white
        : viewModeNotifier.value == .mini
        ? miniViewHighlightTextColor.value
        : lyricsPageHighlightTextColor.value;
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_playStateListener);
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: widget.expanded ? TextAlign.left : TextAlign.center,
      text: TextSpan(children: widget.line.tokens.map(buildTokenSpan).toList()),
    );
  }

  InlineSpan buildTokenSpan(LyricToken token) {
    final start = token.start;
    final end = token.end;

    double progress;
    if (displayPosition <= start) {
      progress = 0;
    } else if (displayPosition >= end!) {
      progress = 1;
    } else {
      progress =
          (displayPosition - start).inMilliseconds /
          (end - start).inMilliseconds;
    }

    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.bold,
      color: textColor,
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Stack(
        children: [
          Text(
            token.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: Colors.transparent,
              shadows: widget.isDesktopLyrics
                  ? [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: isMobile ? 5 : 1,
                        color: isMobile ? Colors.black87 : Colors.black54,
                      ),
                    ]
                  : null,
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              final p = progress.clamp(0.0, 1.0);
              return LinearGradient(
                colors: [textColor, textColor.withAlpha(128)],
                stops: [p, p],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
            },
            child: Text(token.text, style: style),
          ),
        ],
      ),
    );
  }
}
