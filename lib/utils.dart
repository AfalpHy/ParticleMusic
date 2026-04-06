import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:image/image.dart' as image;
import 'package:lpinyin/lpinyin.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/landscape_view/extensions/window_controller_extension.dart';
import 'package:particle_music/landscape_view/single_instance.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:path/path.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

void showCenterMessage(
  BuildContext context,
  String message, {
  int duration = 500,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: Colors.black,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(milliseconds: duration), () {
    overlayEntry.remove();
  });
}

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showAnimationDialog<bool>(
    context: context,
    width: isMobile ? 280 : 300,
    height: 180,
    pageBuilder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Align(
              alignment: .centerLeft,
              child: Text(
                action,
                style: TextStyle(fontSize: 25, fontWeight: .bold),
              ),
            ),
            SizedBox(height: 15),
            Align(
              alignment: .centerLeft,
              child: Text(l10n.continueMsg, style: TextStyle(fontSize: 14)),
            ),
            SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(l10n.confirm),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

Widget adaptiveTextField(
  BuildContext context,
  String name,
  TextEditingController controller, {
  bool expand = false,
  bool onlyNumber = false,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 20),
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$name:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),

        SizedBox(
          height: expand ? 180 : null,
          child: TextField(
            keyboardType: onlyNumber ? .number : null,
            readOnly: isMobile,
            expands: expand,
            maxLines: expand ? null : 1,
            style: TextStyle(fontSize: 12),
            controller: controller,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: textColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: textColor, width: 1.5),
              ),
              isDense: true,
            ),
            onTap: () {
              if (isMobile) {
                showTextFieldSheet(
                  context,
                  controller,
                  expand: expand,
                  onlyNumber: onlyNumber,
                );
              }
            },
          ),
        ),
      ],
    ),
  );
}

Future<String> showTextFieldSheet(
  BuildContext context,
  TextEditingController controller, {
  bool expand = false,
  bool needConfirmButton = false,
  bool onlyNumber = false,
}) async {
  return await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (context) {
          final specificTextcolor = colorManager.getSpecificTextColor();

          return MySheet(
            height: 500,
            Column(
              mainAxisAlignment: MainAxisAlignment.start, // center vertically
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor: specificTextcolor.withAlpha(50),
                        cursorColor: specificTextcolor,
                        selectionHandleColor: specificTextcolor,
                      ),
                    ),
                    child: SizedBox(
                      height: expand ? 120 : 60,
                      child: TextField(
                        keyboardType: onlyNumber ? .number : null,
                        expands: expand,
                        maxLines: expand ? null : 1,
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(color: specificTextcolor),
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: specificTextcolor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: specificTextcolor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (needConfirmButton) const SizedBox(height: 10),
                if (needConfirmButton)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        controller.text,
                      ); // close with value
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorManager.getSpecificButtonColor(),
                      foregroundColor: specificTextcolor,
                    ),
                    child: Text(AppLocalizations.of(context).confirm),
                  ),
              ],
            ),
          );
        },
      ) ??
      "";
}

Future<T?> showAnimationDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  double width = 300,
  double height = 450,
  required Widget Function(BuildContext context) pageBuilder,
}) async {
  return await showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, _) {
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (barrierDismissible) {
                  Navigator.pop(context);
                }
              },
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, _) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * animation.value,
                      sigmaY: 5 * animation.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.3 * animation.value,
                      ),
                    ),
                  );
                },
              ),
            ),

            Center(
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      ),
                    ),
                child: FadeTransition(
                  opacity: animation,
                  child: Material(
                    shape: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: colorManager.getSpecificBgBaseColor(),
                    clipBehavior: .antiAliasWithSaveLayer,
                    child: Container(
                      color: colorManager.getSpecificBgColor(),
                      width: width,
                      height: height,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true, // for mobile
                        removeRight: true,
                        removeTop: true,
                        removeBottom: true,
                        child: pageBuilder(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String getTitle(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.title == null || song.title == '') {
    return basename(song.filePath!);
  }
  return song.title!;
}

String getArtist(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.artist == null || song.artist == '') {
    return 'Unknown Artist';
  }
  return song.artist!;
}

String getAlbum(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.album == null || song.album == '') {
    return 'Unknown Album';
  }
  return song.album!;
}

Duration getDuration(MyAudioMetadata? song) {
  if (song == null) {
    return Duration.zero;
  }
  return song.duration ?? Duration.zero;
}

Uint8List? getPictureBytes(MyAudioMetadata? song) {
  return song?.pictureBytes;
}

List<MyAudioMetadata> filterSongList(
  List<MyAudioMetadata> songList,
  String value,
) {
  return songList.where((song) {
    final songTitle = getTitle(song);
    final songArtist = getArtist(song);
    final songAlbum = getAlbum(song);

    return value.isEmpty ||
        songTitle.toLowerCase().contains(value.toLowerCase()) ||
        songArtist.toLowerCase().contains(value.toLowerCase()) ||
        songAlbum.toLowerCase().contains(value.toLowerCase());
  }).toList();
}

void sortSongList(int sortType, List<MyAudioMetadata> songList) {
  switch (sortType) {
    case 1: // Title Ascending
      songList.sort((a, b) {
        return compareMixed(getTitle(a), getTitle(b));
      });
      break;
    case 2: // Title Descending
      songList.sort((a, b) {
        return compareMixed(getTitle(b), getTitle(a));
      });
      break;
    case 3: // Artist Ascending
      songList.sort((a, b) {
        return compareMixed(getArtist(a), getArtist(b));
      });
      break;
    case 4: // Artist Descending
      songList.sort((a, b) {
        return compareMixed(getArtist(b), getArtist(a));
      });
      break;
    case 5: // Album Ascending
      songList.sort((a, b) {
        return compareMixed(getAlbum(a), getAlbum(b));
      });
      break;
    case 6: // Album Descending
      songList.sort((a, b) {
        return compareMixed(getAlbum(b), getAlbum(a));
      });
      break;
    case 7: // Duration Ascending
      songList.sort((a, b) {
        return a.duration!.compareTo(b.duration!);
      });
      break;
    case 8: // Duration Descending
      songList.sort((a, b) {
        return b.duration!.compareTo(a.duration!);
      });
      break;
    default:
      break;
  }
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

bool isEnglish(String s) {
  final c = s[0];
  return RegExp(r'^[A-Za-z]').hasMatch(c);
}

int compareMixed(String a, String b) {
  final aIsEng = isEnglish(a);
  final bIsEng = isEnglish(b);

  if (aIsEng && !bIsEng) return -1;
  if (!aIsEng && bIsEng) return 1;

  if (aIsEng && bIsEng) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  final pa = PinyinHelper.getPinyinE(a);
  final pb = PinyinHelper.getPinyinE(b);
  return pa.compareTo(pb);
}

void tryVibrate() {
  if (vibrationOnNoitifier.value) {
    HapticFeedback.heavyImpact();
  }
}

Future<Uint8List?> loadPictureBytes(MyAudioMetadata? song) async {
  if (song == null) {
    return null;
  }

  if (song.pictureLoaded) {
    return song.pictureBytes;
  }
  final result = song.isNavidrome
      ? await navidromeClient.getPictureBytes(song.id!)
      : await readPictureAsync(song.fullFilePath);
  song.pictureBytes = result;
  song.pictureLoaded = true;
  return result;
}

Future<Color> computeCoverArtColor(MyAudioMetadata? song) async {
  if (song?.coverArtColor != null) {
    return song!.coverArtColor!;
  }
  final bytes = await loadPictureBytes(song);
  if (bytes == null) {
    song?.coverArtColor = Colors.grey;
    return Colors.grey;
  }

  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    song?.coverArtColor = Colors.grey;
    return Colors.grey;
  }

  // simple average of top pixels
  double r = 0, g = 0, b = 0, count = 0;
  for (int y = 0; y < decoded.height; y += 5) {
    for (int x = 0; x < decoded.width; x += 5) {
      final pixel = decoded.getPixel(x, y);
      if (pixel.a == 0) {
        r += 128;
        g += 128;
        b += 128;
      } else {
        r += pixel.r.toDouble();
        g += pixel.g.toDouble();
        b += pixel.b.toDouble();
      }

      count++;
    }
  }
  r /= count;
  g /= count;
  b /= count;
  int luminance = image.getLuminanceRgb(r, g, b).toInt();
  int maxLuminace = 200;
  if (luminance > maxLuminace) {
    r -= luminance - maxLuminace;
    g -= luminance - maxLuminace;
    b -= luminance - maxLuminace;
  }
  final color = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  song!.coverArtColor = color;
  return color;
}

MyAudioMetadata? getFirstSong(List<MyAudioMetadata> songList) {
  if (songList.isEmpty) {
    return null;
  }
  return songList.first;
}

Future<void> setSongList(
  File songFilePathListFile,
  List<MyAudioMetadata> additionalSongList,
  List<MyAudioMetadata> destList,
) async {
  if (!await songFilePathListFile.exists()) {
    await songFilePathListFile.create();
  }

  final jsonString = await songFilePathListFile.readAsString();

  if (jsonString.isNotEmpty) {
    final List<dynamic> songFilePathList = jsonDecode(jsonString);
    for (final path in songFilePathList) {
      if (library.filePathValidSet.contains(path)) {
        final song = library.filePath2Song[path]!;
        destList.add(song);
      } else {
        library.filePath2Song.remove(path);
      }
    }
  }
  destList.addAll(additionalSongList);
}

Future<void> updateDesktopLyrics() async {
  if (isMobile) {
    FlutterOverlayWindow.shareData({
      'position': audioHandler.getPosition().inMicroseconds,
      'lyric_line': currentLyricLine?.toMap(),
      'isKaraoke': currentLyricLineIsKaraoke,
    });
    return;
  }

  await lyricsWindowController?.updateLyric(
    audioHandler.getPosition(),
    currentLyricLine,
    currentLyricLineIsKaraoke,
  );
}

void getDesktopLyricFromMap(dynamic data) {
  final raw = data as Map;
  final map = Map<String, dynamic>.from(raw);

  desktopLyricsCurrentPosition = Duration(microseconds: map['position'] as int);
  final lyricLineMap = map['lyric_line'] as Map?;
  desktopLyricLine = lyricLineMap != null
      ? LyricLine.fromMap(lyricLineMap)
      : null;

  desktopLyricsIsKaraoke = map['isKaraoke'] as bool;
  updateDesktopLyricsNotifier.value++;
}

bool _exited = false;

void exitApp() async {
  if (_exited) {
    return;
  }

  lyricsWindowController!.close();
  await SingleInstance.end();
  // only this allows quick exit on Windows
  if (Platform.isWindows) {
    await windowManager.setPreventClose(false);
    _exited = true;
    windowManager.close();
    return;
  }

  exit(0);
}
