import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

DateTime indexChangeTime = DateTime.fromMillisecondsSinceEpoch(0);

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

List<LyricLine> lyrics = [];
bool _isKaraoke = false;

Duration parseTime(RegExpMatch m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final ms = int.parse(m.group(3)!.padRight(3, '0'));
  return Duration(minutes: min, seconds: sec, milliseconds: ms);
}

Future<void> parseLyricsFile(AudioMetadata song) async {
  lyrics = [];
  _isKaraoke = false;
  List<String> lines = [];
  if (song.lyrics == null) {
    String path = song.file.path;
    path = "${path.substring(0, path.lastIndexOf('.'))}.lrc";
    final file = File(path);
    if (!file.existsSync()) {
      lyrics.add(LyricLine(Duration.zero, 'lyrics file does not exist', []));
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

    if (lyrics.isNotEmpty && lyrics.last.tokens.last.end == null) {
      lyrics.last.tokens.last.end = lineStart;
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
        _isKaraoke = true;
      }
      lyrics.add(LyricLine(lineStart, textBuffer.toString(), tokens));
    }
  }
  if (lyrics.isEmpty) {
    lyrics.add(LyricLine(Duration.zero, 'lyrics parsing failed', []));
  } else {
    if (lyrics.last.tokens.last.end == null) {
      lyrics.last.tokens.last.end = song.duration;
    }
  }
}

class LyricsListView extends StatefulWidget {
  final bool expanded;
  final List<LyricLine> lyrics;

  const LyricsListView({
    super.key,
    required this.expanded,
    required this.lyrics,
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

  bool jump = true;
  Timer? timer;
  late final Ticker ticker;
  final ValueNotifier<int> tickNotifier = ValueNotifier<int>(0);

  void scroll2CurrentIndex(Duration position) {
    // return when loading song and rebuilding this widget
    if (audioHandler.isloading) {
      return;
    }
    int tmp = currentIndexNotifier.value;
    int current = -1;
    int i = 0;
    if (tmp > -1 && position >= widget.lyrics[tmp].start) {
      i = tmp;
    }
    for (; i < widget.lyrics.length; i++) {
      final line = widget.lyrics[i];
      if (position < line.start) {
        break;
      }
      if (current == -1 || line.start > widget.lyrics[current].start) {
        current = i;
      }
    }
    currentIndexNotifier.value = current;

    if (tmp != current) {
      indexChangeTime = DateTime.now();
      if (lyricsWindowId != null) {
        final controller = WindowController.fromWindowId(lyricsWindowId!);
        controller.sendLyricLine(current >= 0 ? widget.lyrics[current] : null);
        controller.sendIsKaraoke(_isKaraoke);
      }
    }

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
    positionSub = audioHandler.getPositionStream().listen(
      (position) => scroll2CurrentIndex(position),
    );
    ticker = createTicker((_) {
      tickNotifier.value++;
    })..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop listening when lyrics page is closed
    positionSub?.cancel();
    positionSub = null;
    ticker.dispose();

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
            itemCount: widget.lyrics.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.35
                      : parentHeight * 0.4,
                );
              } else if (index == widget.lyrics.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.6
                      : parentHeight * 0.45,
                );
              }
              return LyricLineWidget(
                index: index - 1,
                line: widget.lyrics[index - 1],
                currentIndexNotifier: currentIndexNotifier,
                expanded: widget.expanded,
                tickNotifier: tickNotifier,
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
  final ValueNotifier<int> tickNotifier;

  const LyricLineWidget({
    super.key,
    required this.line,
    required this.index,
    required this.currentIndexNotifier,
    required this.expanded,
    required this.tickNotifier,
  });

  double staggeredOffset(int currentIndex, double lineHeight) {
    if (index <= currentIndex) return 0;

    final elapsed =
        DateTime.now().difference(indexChangeTime).inMilliseconds / 1000.0;

    if (elapsed < 0.3) return lineHeight;
    const perLineDelay = 0.05;
    final distance = index - currentIndex;
    final delay = distance * perLineDelay;

    const duration = 0.2;
    final t = ((elapsed - 0.3 - delay) / duration).clamp(0.0, 1.0);

    return lineHeight - t * lineHeight;
  }

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
                  25 + (isMobile ? 0 : (pageHeight - 700) * 0.025),
                  0,
                  25 + (isMobile ? 0 : (pageHeight - 700) * 0.025),
                )
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          child: ValueListenableBuilder(
            valueListenable: currentIndexNotifier,
            builder: (context, currentIndex, child) {
              return ValueListenableBuilder(
                valueListenable: tickNotifier,
                builder: (context, value, child) {
                  final isCurrent = currentIndex == index;

                  double fontSize = 12;
                  if (isCurrent) {
                    fontSize += 6;
                  }
                  if (expanded) {
                    fontSize += 8;
                  }

                  fontSize += isMobile
                      ? 0
                      : min(
                          (pageHeight - 700) * 0.05,
                          (pageWidth - 1050) * 0.025,
                        );

                  if (isCurrent && _isKaraoke) {
                    return StreamBuilder<Duration>(
                      stream: audioHandler.getPositionStream(),
                      builder: (context, snapshot) {
                        return KaraokeText(
                          key: UniqueKey(),
                          line: line,
                          position: snapshot.data ?? Duration.zero,
                          fontSize: fontSize,
                          expanded: expanded,
                        );
                      },
                    );
                  }

                  final offsetY = staggeredOffset(currentIndex, fontSize * 0.7);
                  return Transform.translate(
                    offset: Offset(0, offsetY),
                    child: Text(
                      line.text,
                      textAlign: expanded ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: isCurrent
                            ? Colors.white
                            : Colors.white.withAlpha(96),
                      ),
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

  const KaraokeText({
    super.key,
    required this.line,
    required this.position,
    required this.fontSize,
    required this.expanded,
  });

  @override
  State<KaraokeText> createState() => KaraokeTextState();
}

class KaraokeTextState extends State<KaraokeText>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;

  Duration displayPosition = Duration.zero;
  DateTime lastSyncTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    displayPosition = widget.position;

    ticker = createTicker((_) {
      final elapsed = DateTime.now().difference(lastSyncTime);
      lastSyncTime = DateTime.now();
      if (isPlayingNotifier.value) {
        displayPosition += elapsed;
      }

      setState(() {});
    })..start();
  }

  @override
  void dispose() {
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
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final p = progress.clamp(0.0, 1.0);
          return LinearGradient(
            colors: [Colors.white, Colors.white, Colors.white.withAlpha(96)],
            stops: [0, p, p],
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
        },
        child: Text(token.text, style: style),
      ),
    );
  }
}
