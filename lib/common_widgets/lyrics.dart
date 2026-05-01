import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:charset/charset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

class LyricToken {
  final Duration start;
  final String text;
  Duration? end;

  LyricToken(this.start, this.text, [this.end]);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'end': end?.inMilliseconds,
      'text': text,
    };
  }

  factory LyricToken.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);

    return LyricToken(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      map['end'] != null ? Duration(milliseconds: map['end'] as int) : null,
    );
  }
}

class LyricLine {
  final Duration start;
  final String text;
  final List<LyricToken> tokens;

  List<String> translates = [];

  LyricLine(this.start, this.text, this.tokens);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'text': text,
      'tokens': tokens.map((t) => t.toMap()).toList(),
      'translates': translates,
    };
  }

  factory LyricLine.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    final lyricLine = LyricLine(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      (map['tokens'] as List).map((e) => LyricToken.fromMap(e as Map)).toList(),
    );
    lyricLine.translates = List<String>.from(map['translates']);
    return lyricLine;
  }
}

class ParsedLyrics {
  bool isKaraoke = false;
  List<LyricLine> lyrics = [];
}

Duration parseTime(RegExpMatch m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final ms = int.parse(m.group(3)!.padRight(3, '0'));
  return Duration(minutes: min, seconds: sec, milliseconds: ms);
}

Future<void> setParsedLyrics(MyAudioMetadata song) async {
  if (song.parsedLyrics != null) {
    return;
  }
  ParsedLyrics result = ParsedLyrics();
  song.parsedLyrics = result;

  List<String> lines = [];

  if (song.isNavidrome) {
    final lyrics = await navidromeClient.getLyricsById(song.id);
    if (lyrics != null) {
      lines = lyrics.split(RegExp(r'[\n]'));
    }
  } else {
    if (song.lyrics == null || song.lyrics!.isEmpty) {
      String path = song.path!;
      path = "${path.substring(0, path.lastIndexOf('.'))}.lrc";

      late File lrcFile;
      if (song.isWebdav) {
        lrcFile = File('${tmpDir.path}/particle_music_lyric');
        await downloadFile(
          path,
          lrcFile.path,
          headers: {'Authorization': getWebdavAuth()},
        );
      } else {
        lrcFile = File(path);
      }
      if (lrcFile.existsSync()) {
        try {
          lines = await lrcFile.readAsLines();
        } catch (e) {
          logger.output(e.toString());
          try {
            lines = await lrcFile.readAsLines(encoding: gbk);
          } catch (e) {
            logger.output(e.toString());
          }
        }
      }
    } else {
      lines = song.lyrics!.split(RegExp(r'[\n]'));
    }
  }
  lines.removeWhere((e) => e.isEmpty);
  if (lines.isEmpty) {
    result.lyrics.add(LyricLine(Duration.zero, 'There are no lyrics', []));
    return;
  }

  final lineTimeRegex = RegExp(r'^[\[<](\d{2}):(\d{2})[.:](\d{2,3})[\]>]');
  final wordRegex = RegExp(r'[\[<](\d{2}):(\d{2})[.:](\d{2,3})[\]>]([^\[<]*)');

  for (var line in lines) {
    final lineMatch = lineTimeRegex.firstMatch(line);
    if (lineMatch == null) continue;

    final lineStart = parseTime(lineMatch);

    final lastLyric = result.lyrics.isNotEmpty ? result.lyrics.last : null;
    bool isTranslate = lastLyric?.start == lineStart;

    if (lastLyric?.tokens.last.end == null && !isTranslate) {
      lastLyric?.tokens.last.end = lineStart;
    }

    final tokenMatches = wordRegex.allMatches(line);

    final tokens = <LyricToken>[];
    final textBuffer = StringBuffer();

    for (final match in tokenMatches) {
      final start = parseTime(match);
      final token = match.group(4)!;

      if (tokens.isNotEmpty) {
        tokens.last.end = start;
      }

      if (token.isNotEmpty) {
        tokens.add(LyricToken(start, token));
        textBuffer.write(token);
      }
    }
    if (tokens.isNotEmpty) {
      if (tokens.length == 1 && tokens[0].text.trim().isEmpty) {
        continue;
      }
      if (tokens.length > 1) {
        result.isKaraoke = true;
      }
      if (isTranslate) {
        lastLyric!.translates.add(textBuffer.toString());
      } else {
        result.lyrics.add(LyricLine(lineStart, textBuffer.toString(), tokens));
      }
    }
  }
  if (result.lyrics.isEmpty) {
    result.lyrics.add(LyricLine(Duration.zero, 'Lyrics parsing failed', []));
  } else {
    if (result.lyrics.last.tokens.last.end == null) {
      result.lyrics.last.tokens.last.end = song.duration;
    }
  }
}

class LyricsListView extends StatefulWidget {
  final bool expanded;
  final List<LyricLine> lyrics;
  final bool isKaraoke;
  const LyricsListView({
    super.key,
    required this.expanded,
    required this.lyrics,
    required this.isKaraoke,
  });

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);
  StreamSubscription<Duration>? positionSub;
  bool userDragging = false;
  bool userDragged = false;

  List<LyricLine> lyrics = [];
  bool jump = true;
  Timer? timer;

  void scroll2CurrentIndex(Duration position) async {
    // it's weird that the position is sometimes negative
    if (audioHandler.isLoading || position < Duration.zero) {
      return;
    }
    int tmp = currentIndexNotifier.value;
    int current = -1;

    for (int i = 0; i < lyrics.length; i++) {
      final line = lyrics[i];
      if (position < line.start) {
        break;
      }
      if (current == -1 || line.start > lyrics[current].start) {
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
            alignment: widget.expanded ? 0.25 : 0.3,
          );
        } else {
          itemScrollController.scrollTo(
            index: current + 1,
            duration: Duration(milliseconds: 300), // smooth animation
            curve: Curves.fastOutSlowIn,
            alignment: widget.expanded ? 0.25 : 0.3,
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
    lyrics = widget.lyrics;
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
          alignment: widget.expanded ? 0.25 : 0.3,
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
            itemCount: lyrics.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.25
                      : parentHeight * 0.3,
                );
              } else if (index == lyrics.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.6
                      : parentHeight * 0.45,
                );
              }
              return LyricLineWidget(
                index: index - 1,
                line: lyrics[index - 1],
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
              ? EdgeInsets.fromLTRB(25, paddingHeight, 0, paddingHeight)
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          child: ValueListenableBuilder(
            valueListenable: lyricsFontSizeOffsetChangeNotifier,
            builder: (_, _, _) {
              return ValueListenableBuilder(
                valueListenable: currentIndexNotifier,
                builder: (context, currentIndex, child) {
                  final isCurrent = currentIndex == index;

                  double fontSize = 16 + lyricsFontSizeOffset;

                  if (expanded) {
                    fontSize += isMobile ? 16 : 8;
                  }

                  fontSize += fontSizeOffset;

                  return Column(
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
                                ? lyricsPageHighlightTextColor.value
                                : lyricsPageForegroundColor.value.withAlpha(
                                    128,
                                  ),
                          ),
                        ),
                      for (final translate in line.translates)
                        Text(
                          translate,
                          textAlign: expanded ? .start : .center,
                          style: TextStyle(
                            fontSize: fontSize - 8,
                            fontWeight: .bold,
                            color: lyricsPageForegroundColor.value.withAlpha(
                              128,
                            ),
                          ),
                        ),
                    ],
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
      color: widget.isDesktopLyrics
          ? Colors.white
          : lyricsPageHighlightTextColor.value,
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
                colors: [
                  widget.isDesktopLyrics
                      ? Colors.white
                      : lyricsPageHighlightTextColor.value,
                  widget.isDesktopLyrics
                      ? Colors.white.withAlpha(128)
                      : lyricsPageHighlightTextColor.value.withAlpha(128),
                ],
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
