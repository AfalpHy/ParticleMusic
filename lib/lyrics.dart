import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class LyricLine {
  final Duration timestamp;
  final String text;
  LyricLine(this.timestamp, this.text);
}

List<LyricLine> lyrics = [];

/// Each lyric line listens to currentIndexNotifier
class LyricLineWidget extends StatelessWidget {
  final String text;
  final int index;
  final ValueNotifier<int> currentIndexNotifier;
  final bool expanded;

  const LyricLineWidget({
    super.key,
    required this.text,
    required this.index,
    required this.currentIndexNotifier,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          audioHandler.seek(lyrics[index].timestamp);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: expanded
              ? const EdgeInsets.fromLTRB(30, 10, 0, 10)
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 50),
          child: ValueListenableBuilder(
            valueListenable: currentIndexNotifier,
            builder: (context, value, child) {
              final isCurrent = value == index;
              double fontSize = 14;
              if (isCurrent) {
                fontSize += 4;
              }
              if (expanded) {
                fontSize += 4;
              }
              if (isMobile) {
                return Text(
                  text,
                  textAlign: expanded ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Colors.black
                        : const Color.fromARGB(128, 0, 0, 0),
                  ),
                );
              }
              final pageHeight = MediaQuery.heightOf(context);
              final pageWidth = MediaQuery.widthOf(context);
              final fontSizeOffset = min(
                (pageHeight - 700) * 0.06,
                (pageWidth - 1050) * 0.03,
              );
              return Text(
                text,
                textAlign: expanded ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize + fontSizeOffset,

                  color: isCurrent
                      ? Colors.grey.shade50
                      : Colors.white.withAlpha(64),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> parseLyricsFile(String path) async {
  lyrics = [];
  final file = File(path);
  if (!file.existsSync()) {
    lyrics.add(LyricLine(Duration.zero, 'lyrics file does not exist'));
    return;
  }
  final lines = await file.readAsLines(); // read file line by line

  final regex = RegExp(r'\[(\d{2}):(\d{2})(?::(\d{2,3})|.(\d{2,3}))\](.*)');

  for (var line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final ms = match.group(3) != null
          ? int.parse(match.group(3)!.padRight(3, '0'))
          : int.parse(match.group(4)!.padRight(3, '0'));
      final text = match.group(5)!.trim();
      if (text == '') {
        continue;
      }
      lyrics.add(
        LyricLine(Duration(minutes: min, seconds: sec, milliseconds: ms), text),
      );
    }
  }
  if (lyrics.isEmpty) {
    lyrics.add(LyricLine(Duration.zero, 'lyrics parsing failed'));
  }
}

class LyricsListView extends StatefulWidget {
  final bool expanded;
  const LyricsListView({super.key, required this.expanded});

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

  bool jump = true;
  Timer? timer;

  void scroll2CurrentIndex(Duration position) {
    // return when loading song and rebuilding this widget
    if (audioHandler.isloading) {
      return;
    }
    int tmp = currentIndexNotifier.value;
    int current = lyrics.lastIndexWhere((line) => position >= line.timestamp);
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
            curve: Curves.linear,
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
                text: lyrics[index - 1].text,
                index: index - 1,
                currentIndexNotifier: currentIndexNotifier,
                expanded: widget.expanded,
              );
            },
          ),
        );
      },
    );
  }
}
