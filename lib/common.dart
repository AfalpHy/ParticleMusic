import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:marquee/marquee.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/setting.dart';
import 'package:path/path.dart';
import 'package:smooth_corner/smooth_corner.dart';

final isMobile = Platform.isAndroid || Platform.isIOS;
final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

const Color mainColor = Color.fromARGB(255, 120, 230, 230);
final Color commonColor = Color.fromARGB(255, 235, 240, 245);

late double appWidth;

const AssetImage addImage = AssetImage('assets/images/add.png');
const AssetImage albumImage = AssetImage('assets/images/album.png');
const AssetImage arrowDownImage = AssetImage('assets/images/arrow_down.png');
const AssetImage artistImage = AssetImage('assets/images/artist.png');
const AssetImage closeImage = AssetImage('assets/images/close.png');
const AssetImage deleteImage = AssetImage('assets/images/delete.png');
const AssetImage folderImage = AssetImage('assets/images/folder.png');
const AssetImage fullscreenExitImage = AssetImage(
  'assets/images/fullscreen_exit.png',
);
const AssetImage fullscreenImage = AssetImage('assets/images/fullscreen.png');
const AssetImage gridImage = AssetImage('assets/images/grid.png');
const AssetImage infoImage = AssetImage('assets/images/info.png');
const AssetImage languageImage = AssetImage('assets/images/language.png');
const AssetImage listImage = AssetImage('assets/images/list.png');
const AssetImage longArrowDownImage = AssetImage(
  'assets/images/long_arrow_down.png',
);
const AssetImage longArrowUpImage = AssetImage(
  'assets/images/long_arrow_up.png',
);
const AssetImage loopImage = AssetImage('assets/images/loop.png');
const AssetImage maximizeImage = AssetImage('assets/images/maximize.png');
const AssetImage minimizeImage = AssetImage('assets/images/minimize.png');
const AssetImage musicNoteImage = AssetImage('assets/images/music_note.png');
const AssetImage nextButtonImage = AssetImage('assets/images/next_button.png');
const AssetImage pauseCircleImage = AssetImage(
  'assets/images/pause_circle.png',
);
const AssetImage pictureImage = AssetImage('assets/images/picture.png');

const AssetImage playCircleFillImage = AssetImage(
  'assets/images/play_circle_fill.png',
);
const AssetImage playCircleImage = AssetImage('assets/images/play_circle.png');
const AssetImage playlistAddImage = AssetImage(
  'assets/images/playlist_add.png',
);
const AssetImage playlistsImage = AssetImage('assets/images/playlists.png');
const AssetImage playnextCircleImage = AssetImage(
  'assets/images/playnext_circle.png',
);
const AssetImage previousButtonImage = AssetImage(
  'assets/images/previous_button.png',
);
const AssetImage reloadImage = AssetImage('assets/images/reload.png');
const AssetImage reorderImage = AssetImage('assets/images/reorder.png');
const AssetImage repeatImage = AssetImage('assets/images/repeat.png');
const AssetImage selectImage = AssetImage('assets/images/select.png');
const AssetImage sequenceImage = AssetImage('assets/images/sequence.png');
const AssetImage shuffleImage = AssetImage('assets/images/shuffle.png');
const AssetImage songsImage = AssetImage('assets/images/songs.png');
const AssetImage timerImage = AssetImage('assets/images/timer.png');
const AssetImage unmaximizeImage = AssetImage('assets/images/unmaximize.png');
const AssetImage vibrationImage = AssetImage('assets/images/vibration.png');

class MyAutoSizeText extends AutoSizeText {
  final String content;

  final TextStyle textStyle;
  MyAutoSizeText(
    this.content, {
    super.key,
    super.maxLines,
    required this.textStyle,
  }) : super(
         content,
         style: textStyle,
         minFontSize: textStyle.fontSize ?? 12,
         maxFontSize: textStyle.fontSize ?? double.infinity,
         overflowReplacement: Marquee(
           text: content,
           style: textStyle,
           scrollAxis: Axis.horizontal,
           blankSpace: 20,
           velocity: 30,
           pauseAfterRound: const Duration(seconds: 1),
           accelerationDuration: const Duration(milliseconds: 500),
           accelerationCurve: Curves.linear,
           decelerationDuration: const Duration(milliseconds: 500),
           decelerationCurve: Curves.linear,
         ),
       );
}

Widget mySheet(Widget child, {double height = 500}) {
  return SmoothClipRRect(
    smoothness: 1,
    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    child: Container(height: height, color: Colors.grey.shade50, child: child),
  );
}

void showCenterMessage(
  BuildContext context,
  String message, {
  int duration = 500,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
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
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(milliseconds: duration), () {
    overlayEntry.remove();
  });
}

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Color.fromARGB(255, 240, 245, 250),
        title: Text(action),
        content: Text(l10n.continueMsg, style: TextStyle(fontSize: 14)),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Color.fromARGB(255, 240, 245, 250),
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.black,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Color.fromARGB(255, 240, 245, 250),
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.red,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result!;
}

String getTitle(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.title == null || song.title == '') {
    return basename(song.file.path);
  }
  return song.title!;
}

String getArtist(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.artist == null || song.artist == '') {
    return 'Unknown Artist';
  }
  return song.artist!;
}

String getAlbum(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.album == null || song.album == '') {
    return 'Unknown Album';
  }
  return song.album!;
}

Duration getDuration(AudioMetadata? song) {
  if (song == null) {
    return Duration.zero;
  }
  return song.duration ?? Duration.zero;
}

Picture? getCoverArt(AudioMetadata? song) {
  if (song == null) {
    return null;
  }
  return song.pictures.isNotEmpty ? song.pictures.first : null;
}

List<AudioMetadata> filterSongs(List<AudioMetadata> songList, String value) {
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

void sortSongs(int sortType, List<AudioMetadata> songList) {
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
