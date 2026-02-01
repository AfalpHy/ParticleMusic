import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
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

  LyricLine(this.start, this.text, this.tokens);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'text': text,
      'tokens': tokens.map((t) => t.toMap()).toList(),
    };
  }

  factory LyricLine.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);

    return LyricLine(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      (map['tokens'] as List).map((e) => LyricToken.fromMap(e as Map)).toList(),
    );
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
  ParsedLyrics result = ParsedLyrics();
  song.parsedLyrics = result;

  List<String> lines = [];
  if (song.lyrics == null) {
    String path = song.filePath;
    path = "${path.substring(0, path.lastIndexOf('.'))}.lrc";
    final file = File(path);
    if (!file.existsSync()) {
      result.lyrics.add(
        LyricLine(Duration.zero, 'lyrics file does not exist', []),
      );
      return;
    }
    lines = await file.readAsLines(); // read file line by line
  } else {
    lines = song.lyrics!.split(RegExp(r'[\n]'));
  }

  final lineTimeRegex = RegExp(r'^\[(\d{2}):(\d{2})[.:](\d{2,3})\]');
  final wordRegex = RegExp(r'\[(\d{2}):(\d{2})[.:](\d{2,3})\]([^\[]*)');

  for (var line in lines) {
    final lineMatch = lineTimeRegex.firstMatch(line);
    if (lineMatch == null) continue;

    final lineStart = parseTime(lineMatch);

    if (result.lyrics.isNotEmpty &&
        result.lyrics.last.tokens.last.end == null) {
      result.lyrics.last.tokens.last.end = lineStart;
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
      result.lyrics.add(LyricLine(lineStart, textBuffer.toString(), tokens));
    }
  }
  if (result.lyrics.isEmpty) {
    result.lyrics.add(LyricLine(Duration.zero, 'lyrics parsing failed', []));
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
    int tmp = currentIndexNotifier.value;
    int current = 0;

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
            alignment: widget.expanded ? 0.35 : 0.4,
          );
        } else {
          itemScrollController.scrollTo(
            index: current + 1,
            duration: Duration(milliseconds: 300), // smooth animation
            curve: Curves.bounceInOut,
            alignment: widget.expanded ? 0.35 : 0.4,
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
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(
          index: currentIndexNotifier.value + 1,
          alignment: widget.expanded ? 0.35 : 0.4,
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
                      ? parentHeight * 0.35
                      : parentHeight * 0.4,
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
    final pageHeight = MediaQuery.heightOf(context);
    final pageWidth = MediaQuery.widthOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          audioHandler.seek(line.start);
        },
        customBorder: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: expanded
              ? EdgeInsets.fromLTRB(
                  25,
                  10 + (isMobile ? 0 : (pageHeight - 700) * 0.025),
                  0,
                  10 + (isMobile ? 0 : (pageHeight - 700) * 0.025),
                )
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          child: ValueListenableBuilder(
            valueListenable: lyricsFontSizeOffsetChangeNotifier,
            builder: (_, _, _) {
              return ValueListenableBuilder(
                valueListenable: currentIndexNotifier,
                builder: (context, currentIndex, child) {
                  final isCurrent = currentIndex == index;

                  double fontSize = 14 + lyricsFontSizeOffset;
                  if (isCurrent) {
                    fontSize += 4;
                  }
                  if (expanded) {
                    fontSize += 4;
                  }

                  fontSize += isMobile
                      ? 0
                      : min(
                          (pageHeight - 700) * 0.05,
                          (pageWidth - 1050) * 0.025,
                        ).clamp(0, double.maxFinite);

                  if (isCurrent && isKaraoke) {
                    return ValueListenableBuilder(
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
                    );
                  }
                  return Text(
                    line.text,
                    textAlign: expanded ? TextAlign.left : TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: isCurrent
                          ? Colors.white
                          : Colors.white.withAlpha(96),
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

  late final VoidCallback _playStateListener;

  @override
  void initState() {
    super.initState();

    displayPosition = widget.position;

    ticker = createTicker((_) {
      final now = DateTime.now();
      final elapsed = now.difference(lastSyncTime);
      lastSyncTime = now;

      displayPosition += elapsed;
      setState(() {});
    });

    _playStateListener = () {
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
    };

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

    final style = TextStyle(fontSize: widget.fontSize, color: Colors.white);

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
                  ? const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 1,
                        color: Colors.black54,
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
                  Colors.white,
                  Colors.white,
                  Colors.white.withAlpha(96),
                ],
                stops: [0, p, p],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
            },
            child: Text(token.text, style: style),
          ),
        ],
      ),
    );
  }
}
