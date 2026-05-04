import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:lpinyin/lpinyin.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/extensions/window_controller_extension.dart';
import 'package:particle_music/landscape_view/keyboard.dart';
import 'package:particle_music/landscape_view/single_instance.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/picture_load_scheduler.dart';
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
    child: Builder(
      builder: (context) {
        return SizedBox(
          width: 300,
          height: 180,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                buttonColor.valueNotifier,
                lyricsPageForegroundColor.valueNotifier,
                lyricsPageButtonColor.valueNotifier,
              ]),
              builder: (context, _) {
                return Column(
                  children: [
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: .bold,
                          color: colorManager.getSpecificTextColor(),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        l10n.continueMsg,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorManager.getSpecificTextColor(),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: colorManager
                                .getSpecificTextColor(),
                          ),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: Colors.red,
                          ),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
  return result ?? false;
}

Widget adaptiveTextField(
  BuildContext context,
  String? name,
  TextEditingController controller, {
  bool expand = false,
  bool onlyNumber = false,
  bool compact = true,
}) {
  FocusNode wrapNode = FocusNode();
  FocusNode textFieldNode = FocusNode();
  final canRequestNotifier = ValueNotifier(false);
  textFieldNode.addListener(() {
    isTyping = textFieldNode.hasFocus;
  });
  return Column(
    children: [
      if (name != null)
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$name:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),

      Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (!isTV) {
            return .ignored;
          }
          if (event is KeyDownEvent && textFieldNode.hasFocus) {
            if (event.logicalKey == .select) {
              textFieldNode.unfocus();
              Future.delayed((Duration(milliseconds: 100)), () {
                textFieldNode.requestFocus();
              });
            } else {
              canRequestNotifier.value = false;
              wrapNode.requestFocus();
            }
            return .handled;
          }
          return .ignored;
        },
        child: InkWell(
          focusNode: wrapNode,
          onTap: isTV
              ? () {
                  canRequestNotifier.value = true;
                  Future.delayed((Duration(milliseconds: 100)), () {
                    textFieldNode.requestFocus();
                  });
                }
              : null,
          child: ValueListenableBuilder(
            valueListenable: canRequestNotifier,
            builder: (context, value, child) {
              final specificTextcolor = colorManager.getSpecificTextColor();
              return Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(
                    selectionColor: specificTextcolor.withAlpha(50),
                    cursorColor: specificTextcolor,
                    selectionHandleColor: specificTextcolor,
                  ),
                ),
                child: TextField(
                  focusNode: textFieldNode,
                  canRequestFocus: isTV ? value : true,
                  keyboardType: onlyNumber ? .number : null,
                  minLines: expand ? 3 : 1,
                  maxLines: expand ? null : 1,
                  style: TextStyle(fontSize: 12),
                  controller: controller,
                  decoration: InputDecoration(
                    visualDensity: compact ? .new(vertical: -3) : null,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: specificTextcolor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: specificTextcolor,
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

Future<T?> showAnimationDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  required Widget child,
}) async {
  Offset offset = Offset.zero;

  final GlobalKey childKey = GlobalKey();
  double childHeight = 0;
  void measureChild() {
    final renderBox = childKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final newHeight = renderBox.size.height;
      if (newHeight != childHeight) {
        childHeight = newHeight;
      }
    }
  }

  return await showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, _) {
      return StatefulBuilder(
        builder: (context, setState) {
          final mediaQuery = MediaQuery.of(context);
          final screenHeight = mediaQuery.size.height;
          final keyboardHeight = mediaQuery.viewInsets.bottom;
          final isKeyboardOpen = keyboardHeight > 0;
          double getMinOffset() {
            if (childHeight == 0) return double.negativeInfinity;
            return screenHeight / 2 - keyboardHeight - childHeight / 2 - 30;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            measureChild();
            if (!isKeyboardOpen && offset != .zero) {
              setState(() {
                offset = .zero;
              });
            }
          });

          return Stack(
            children: [
              AnimatedBuilder(
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

              ModalBarrier(
                dismissible: barrierDismissible,
                color: Colors.black.withValues(alpha: 0.3 * animation.value),
                onDismiss: () {
                  Navigator.pop(context);
                },
              ),

              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, offset.dy, 0),
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (!isKeyboardOpen) return;

                      setState(() {
                        if (offset.dy < getMinOffset() || offset.dy > 0) {
                          offset += Offset(0, details.delta.dy * 0.15);
                        } else {
                          offset += Offset(0, details.delta.dy);
                        }
                      });
                    },

                    onVerticalDragEnd: (_) {
                      if (!isKeyboardOpen) return;

                      final minOffset = getMinOffset();
                      setState(() {
                        if (offset.dy < minOffset) {
                          offset = Offset(0, minOffset);
                        } else if (offset.dy > 0) {
                          offset = .zero;
                        }
                      });
                    },

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
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            layersManager.backgroundChangeNotifier,
                            currentSongNotifier,
                            pageBackgroundColor.valueNotifier,
                            panelColor.valueNotifier,
                          ]),
                          builder: (context, _) {
                            return Material(
                              key: childKey,
                              shape: SmoothRectangleBorder(
                                smoothness: 1,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: colorManager.getSpecificBgBaseColor(),
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              child: Container(
                                color: colorManager.getSpecificBgColor(),
                                child: MediaQuery.removePadding(
                                  context: context,
                                  removeLeft: true,
                                  removeRight: true,
                                  removeTop: true,
                                  removeBottom: true,
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

String getTitle(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.title == null || song.title == '') {
    return basename(song.id);
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

List<String> getArtists(String artist) {
  List<String> artists = [];
  for (String artistName in artist.split(RegExp(r'[/&,]'))) {
    if (artistName.isEmpty) {
      return [artist];
    }
    artists.add(artistName);
  }
  return artists;
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

String getAlbumArtist(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.albumArtist == null || song.albumArtist == '') {
    return 'Unknown Album Artist';
  }
  return song.albumArtist!;
}

String getGenre(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.genre == null || song.genre == '') {
    return 'Unknown Genre';
  }
  return song.genre!;
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
    case 9: // modified time Ascending
      songList.sort((a, b) {
        return a.modified!.compareTo(b.modified!);
      });
    case 10: // modified time Descending
      songList.sort((a, b) {
        return b.modified!.compareTo(a.modified!);
      });
    case 11:
      songList.shuffle();
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

bool _isEnglish(String s) {
  final c = s[0];
  return RegExp(r'^[A-Za-z]').hasMatch(c);
}

int compareMixed(String a, String b) {
  final aIsEng = _isEnglish(a);
  final bIsEng = _isEnglish(b);

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

Future<Uint8List?> loadPictureBytesSafe(MyAudioMetadata? song) async {
  if (song == null) {
    return null;
  }

  if (song.pictureLoaded) {
    return song.pictureBytes;
  }

  return pictureLoadScheduler.load(song.id, () => _loadPictureBytes(song));
}

Future<Uint8List?> _loadPictureBytes(MyAudioMetadata song) async {
  try {
    late Uint8List? result;
    if (song.isNavidrome) {
      if (song.navidromeCachePath != null) {
        result = await readPictureAsync(song.navidromeCachePath!);
      } else {
        result = await navidromeClient.getPictureBytes(song.id);
      }
    } else if (song.isWebdav) {
      if (song.webdavCachePath != null) {
        result = await readPictureAsync(song.webdavCachePath!);
      } else {
        result = await readPictureAsync(
          song.path!,
          username: webdavUsername,
          password: webdavPassword,
        );
      }
    } else {
      result = await readPictureAsync(song.path!);
    }

    song.pictureBytes = result;
    song.pictureLoaded = true;
    return result;
  } catch (e) {
    song.pictureBytes = null;
    song.pictureLoaded = true;
    logger.output(e.toString());
  }
  return null;
}

Future<Color> computeCoverArtColor(MyAudioMetadata? song) async {
  if (song?.coverArtColor != null) {
    return song!.coverArtColor!;
  }
  final bytes = await loadPictureBytesSafe(song);
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
  final color = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  song!.coverArtColor = color;

  int luminance = image.getLuminanceRgb(r, g, b).toInt();
  int maxLuminace = 200;
  if (luminance > maxLuminace) {
    r -= luminance - maxLuminace;
    g -= luminance - maxLuminace;
    b -= luminance - maxLuminace;
    song.lowerLuminance = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  }

  return color;
}

MyAudioMetadata? getFirstSong(List<MyAudioMetadata> songList) {
  if (songList.isEmpty) {
    return null;
  }
  return songList.first;
}

Future<void> setSongList(
  File songIdListFile,
  List<MyAudioMetadata> destList,
  Map<String, MyAudioMetadata> id2Song,
) async {
  final jsonString = await songIdListFile.readAsString();

  final List<dynamic> songIdList = jsonDecode(jsonString);
  for (final id in songIdList) {
    final song = id2Song[id];
    if (song != null) {
      destList.add(song);
    }
  }
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

Future<List<String>> getWebdavSubDirectoriesFrom(String root) async {
  List<String> dirList = [];
  Queue<String> dirQueue = Queue();
  dirQueue.add(root);
  while (dirQueue.isNotEmpty) {
    String dir = dirQueue.first;
    dirQueue.removeFirst();
    final fileList = await webdavClient!.readDir(dir);
    for (final f in fileList) {
      if (f.isDir!) {
        final tmpPath = f.path!.substring(0, f.path!.length - 1);
        dirList.add(tmpPath);
        dirQueue.add(tmpPath);
      }
    }
  }
  return dirList;
}

bool isFileProviderStorePath(String path) {
  return path.contains('File Provider Storage/');
}

// full path to short path
String convertIOSPath(String path) {
  if (path.contains('File Provider Storage/')) {
    return path.split('File Provider Storage/').last;
  } else {
    path = path.substring(path.indexOf('Documents'));
    return path.replaceFirst('Documents', 'Particle Music');
  }
}

// short path to full path
String revertIOSPath(String path) {
  if (path.startsWith('Particle Music')) {
    return "${appDocs.parent.path}/${path.replaceFirst('Particle Music', 'Documents')}";
  } else {
    if (library.iosFileProviderStorage == null) {
      return '';
    }
    return library.iosFileProviderStorage! + path;
  }
}

// full path to short path
String convertIOSSupportPath(String path) {
  return path.split('Application Support/').last;
}

// short path to full path
String revertIOSSupportPath(String path) {
  return "${appSupportDir.path}/$path";
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

String getWebdavAuth() {
  return 'Basic ${base64Encode(utf8.encode('$webdavUsername:$webdavPassword'))}';
}

Future<void> downloadFile(
  String url,
  String savePath, {
  Map<String, String>? headers,
}) async {
  try {
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      logger.output('$url download failed');
    }
  } catch (e) {
    logger.output(e.toString());
  }
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
